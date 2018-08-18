#pragma once

#include <string>
#include <vector>

#include "types.hpp"

bool ReadFile(const std::string& filePath, std::vector<char>& vec, bool bBinaryFile);

std::string IntToString(i32 i, i32 minChars = 0);
