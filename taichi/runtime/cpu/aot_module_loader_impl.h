#pragma once

#include "taichi/aot/module_loader.h"

namespace taichi {
namespace lang {

class LlvmRuntimeExecutor;

namespace cpu {

struct TI_DLL_EXPORT AotModuleParams {
  std::string module_path;
  LlvmRuntimeExecutor *executor_{nullptr};
};

TI_DLL_EXPORT std::unique_ptr<aot::Module> make_aot_module(std::any mod_params);

}  // namespace cpu
}  // namespace lang
}  // namespace taichi
