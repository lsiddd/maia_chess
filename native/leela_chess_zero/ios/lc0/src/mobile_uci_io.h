/*
  Private UCI transport used by the Flutter FFI bridge.

  lc0 and Stockfish run in the same Android process. Redirecting file
  descriptors 0/1 and then using the process-wide std::cin/std::cout objects
  makes the two engines contend for the same streams. Keep lc0 on its own
  pipes instead.
*/
#ifndef LC0_MOBILE_UCI_IO_H_
#define LC0_MOBILE_UCI_IO_H_

#include <string>

namespace lczero {

bool ReadMobileUciInput(std::string* line);
void WriteMobileUciOutput(const std::string& line);

}  // namespace lczero

#endif  // LC0_MOBILE_UCI_IO_H_
