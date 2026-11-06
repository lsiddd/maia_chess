# Maia-3 79M FP32

Source: [CSSLab/maia3](https://github.com/CSSLab/maia3), commit
`1e13597c42d4858b7cfd7cfdae01e297263364b2`.
Official weights: [UofTCSSLab/Maia3-79M](https://huggingface.co/UofTCSSLab/Maia3-79M),
revision `a107d6ceb7b298cb04ae1da4edffe2939858b894`.
Copyright belongs to the Maia-3 authors. Code and weights are AGPL-3.0;
see `LICENSE-AGPL-3.0.txt`.

`maia3-79m-fp32.onnx` is the official checkpoint's move policy, converted once
outside this repository. No training or quantization was performed. Unused
value and thinking-time outputs are pruned. RMSNorm is decomposed as
`x * rsqrt(mean(x*x) + eps) * weight`, with the original FP32 epsilon.
Export uses ONNX opset 17, batch size 1, `[1,64,96]` FP32 historical square
tokens and two `[1]` int64 Elo inputs. The output is `[1,4352]` FP32 logits.

`manifest.json` records source and artifact hashes and export validation.
PyTorch reference fixtures are checked in as test data, with no Python code or
Python build dependency. All application model handling is in Dart, using
ONNX Runtime through FFI for numerical inference. Android only exposes its
APK file paths so Dart can stream the bundled model without a large RAM copy.

The model is tracked by Git LFS. Run `git lfs install` and `git lfs pull` after
cloning, then `dart run tool/verify_maia3.dart`. A release APK includes the full
model, requires no network permission and performs no downloads.

Paper: Daniel Monroe, George Eilender, Philip Chalmers, Zhenwei Tang and
Ashton Anderson, *Chessformer: A Unified Architecture for Chess Modeling*,
ICLR 2026. https://openreview.net/forum?id=2ltBRzEHyd
