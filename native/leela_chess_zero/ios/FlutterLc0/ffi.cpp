#include <iostream>
#include <cstdio>
#include <cstring>
#include <cerrno>
#include <mutex>
#include <unistd.h>
#include <string>
#include <stdexcept>

#ifdef __ANDROID__
#include <android/log.h>
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, "LC0_FFI", __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, "LC0_FFI", __VA_ARGS__)
#else
#define LOGD(...) fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n")
#define LOGE(...) fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n")
#endif

#include "ffi.h"
#include "../lc0/src/mobile_uci_io.h"

// lc0 main function declaration
int main(int argc, const char** argv);

// Pipe management for stdin/stdout redirection
#define NUM_PIPES 2
#define PARENT_WRITE_PIPE 0
#define PARENT_READ_PIPE 1
#define READ_FD 0
#define WRITE_FD 1
#define PARENT_READ_FD (pipes[PARENT_READ_PIPE][READ_FD])
#define PARENT_WRITE_FD (pipes[PARENT_WRITE_PIPE][WRITE_FD])
#define CHILD_READ_FD (pipes[PARENT_WRITE_PIPE][READ_FD])
#define CHILD_WRITE_FD (pipes[PARENT_READ_PIPE][WRITE_FD])

static int pipes[NUM_PIPES][2] = {{-1, -1}, {-1, -1}};
static char buffer[4096];
static std::string weightsPath;
static std::mutex pipe_mutex;
static std::mutex stdin_mutex;
static std::mutex stdout_mutex;
static bool mainRunning = false;

static void CloseFd(int& fd)
{
    if (fd >= 0) {
        close(fd);
        fd = -1;
    }
}

extern "C" {

int lc0_init()
{
    std::lock_guard<std::mutex> lock(pipe_mutex);
    if (mainRunning || PARENT_READ_FD >= 0 || PARENT_WRITE_FD >= 0 ||
        CHILD_READ_FD >= 0 || CHILD_WRITE_FD >= 0) {
        LOGE("Previous lc0 pipes have not finished shutting down");
        return -3;
    }
    LOGD("lc0_init() called");
    if (pipe(pipes[PARENT_READ_PIPE]) != 0) {
        LOGE("Failed to create PARENT_READ_PIPE");
        return -1;
    }
    if (pipe(pipes[PARENT_WRITE_PIPE]) != 0) {
        LOGE("Failed to create PARENT_WRITE_PIPE");
        CloseFd(PARENT_READ_FD);
        CloseFd(CHILD_WRITE_FD);
        return -2;
    }
    weightsPath.clear();
    LOGD("lc0_init() completed successfully");
    return 0;
}

void lc0_abort_startup(int stdout_started)
{
    std::scoped_lock lock(pipe_mutex, stdin_mutex, stdout_mutex);
    if (mainRunning) return;
    CloseFd(CHILD_WRITE_FD);
    CloseFd(CHILD_READ_FD);
    CloseFd(PARENT_WRITE_FD);
    // A started reader owns its descriptor and wakes on EOF. It must close
    // that descriptor itself before a later initialization can reuse pipes.
    if (!stdout_started) CloseFd(PARENT_READ_FD);
}

void lc0_set_weights(const char* path)
{
    std::lock_guard<std::mutex> lock(pipe_mutex);
    if (mainRunning) return;
    if (path != nullptr) {
        weightsPath = path;
        LOGD("lc0_set_weights() set path to: %s", path);
    } else {
        LOGE("lc0_set_weights() called with null path");
    }
}

int lc0_main()
{
    std::string weights;
    {
        std::lock_guard<std::mutex> lock(pipe_mutex);
        if (mainRunning || CHILD_READ_FD < 0 || CHILD_WRITE_FD < 0) return 1;
        mainRunning = true;
    }

    // Do not dup2() these pipes over the process-wide stdin/stdout. Stockfish
    // is another in-process FFI engine and also redirects fd 0/1. Sharing
    // std::cin caused its UCI loop to sleep forever behind lc0's blocking
    // getline(). The lc0 UCI loop reads/writes these pipes directly through
    // ReadMobileUciInput/WriteMobileUciOutput below.
    LOGD("Using private UCI pipes, about to call main()...");

    int exitCode;

    try {
        weights = weightsPath;
        LOGD("lc0_main() called, weightsPath=%s", weights.c_str());
        if (!weights.empty()) {
            FILE* f = fopen(weights.c_str(), "r");
            if (f) {
                fclose(f);
                LOGD("Weights file exists and is readable");
            } else {
                LOGE("WARNING: Cannot open weights file: %s", weights.c_str());
            }

            // Just pass weights, let lc0 use DEFAULT_BACKEND
            std::string weightsArg = "--weights=" + weights;
            LOGD("Calling lc0 main with args: lc0 %s", weightsArg.c_str());
            const char *argv[] = {"lc0", weightsArg.c_str()};
            exitCode = main(2, argv);
        } else {
            LOGD("Calling lc0 main without weights");
            const char *argv[] = {"lc0"};
            exitCode = main(1, argv);
        }
    } catch (std::exception& e) {
        LOGE("lc0 main threw exception: %s", e.what());
        exitCode = 1;
    } catch (...) {
        LOGE("lc0 main threw unknown exception");
        exitCode = 1;
    }

    LOGD("lc0 main returned with exitCode=%d", exitCode);
    lczero::WriteMobileUciOutput("quitok");
    // Make the stdout reader observe EOF even if "quitok" happened to be
    // coalesced with another pipe read.
    {
        std::scoped_lock lock(pipe_mutex, stdin_mutex, stdout_mutex);
        CloseFd(CHILD_WRITE_FD);
        CloseFd(CHILD_READ_FD);
        CloseFd(PARENT_WRITE_FD);
        mainRunning = false;
    }

    return exitCode;
}

ssize_t lc0_stdin_write(char *data)
{
    if (data == nullptr) {
        return 0;
    }
    std::lock_guard<std::mutex> write_lock(stdin_mutex);
    int fd;
    {
        std::lock_guard<std::mutex> lock(pipe_mutex);
        fd = PARENT_WRITE_FD;
    }
    if (fd < 0) return -1;
    const size_t length = strlen(data);
    size_t written = 0;
    while (written < length) {
        const ssize_t count =
            write(fd, data + written, length - written);
        if (count > 0) {
            written += static_cast<size_t>(count);
            continue;
        }
        if (count < 0 && errno == EINTR) {
            continue;
        }
        return count;
    }
    return static_cast<ssize_t>(written);
}

char *lc0_stdout_read()
{
    int fd;
    {
        std::lock_guard<std::mutex> lock(pipe_mutex);
        fd = PARENT_READ_FD;
    }
    if (fd < 0) return nullptr;
    ssize_t count;
    do {
        count = read(fd, buffer, sizeof(buffer) - 1);
    } while (count < 0 && errno == EINTR);
    if (count <= 0) {
        std::lock_guard<std::mutex> lock(pipe_mutex);
        CloseFd(PARENT_READ_FD);
        return nullptr;
    }

    buffer[count] = '\0';
    return buffer;
}

} // extern "C"

namespace lczero {

bool ReadMobileUciInput(std::string* line)
{
    if (line == nullptr) {
        return false;
    }
    int fd;
    {
        std::lock_guard<std::mutex> lock(pipe_mutex);
        fd = CHILD_READ_FD;
    }
    if (fd < 0) return false;

    line->clear();
    char value;
    while (true) {
        const ssize_t count = read(fd, &value, 1);
        if (count == 1) {
            if (value == '\n') {
                return true;
            }
            if (value != '\r') {
                line->push_back(value);
            }
            continue;
        }
        if (count < 0 && errno == EINTR) {
            continue;
        }
        return false;
    }
}

void WriteMobileUciOutput(const std::string& line)
{
    std::lock_guard<std::mutex> write_lock(stdout_mutex);
    int fd;
    {
        std::lock_guard<std::mutex> lock(pipe_mutex);
        fd = CHILD_WRITE_FD;
    }
    if (fd < 0) return;

    const std::string data = line + '\n';
    size_t written = 0;
    while (written < data.size()) {
        const ssize_t count =
            write(fd, data.data() + written, data.size() - written);
        if (count > 0) {
            written += static_cast<size_t>(count);
            continue;
        }
        if (count < 0 && errno == EINTR) {
            continue;
        }
        LOGE("Failed to write lc0 UCI output");
        return;
    }
}

}  // namespace lczero
