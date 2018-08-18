
#include "Helpers.hpp"

#include <iostream>
#include <fstream>
#include <string>

#include "types.hpp"


bool ReadFile(const std::string& filePath, std::vector<char>& vec, bool bBinaryFile)
{
	i32 fileMode = std::ios::in | std::ios::ate;
	if (bBinaryFile)
	{
		fileMode |= std::ios::binary;
	}
	std::ifstream file(filePath.c_str(), fileMode);

	if (!file)
	{
		//PrintError("Unable to read file: %s\n", filePath.c_str());
		return false;
	}

	std::streampos length = file.tellg();

	vec.resize((size_t)length);

	file.seekg(0, std::ios::beg);
	file.read(vec.data(), length);
	file.close();

	return true;
}

std::string IntToString(i32 i, i32 minChars)
{
	std::string result = std::to_string(abs(i));

	if (i < 0)
	{
		if ((i32)result.length() < minChars)
		{
			result = '-' + std::string(minChars - result.length(), '0') + result;
		}
		else
		{
			result = '-' + result;
		}
	}
	else
	{
		if ((i32)result.length() < minChars)
		{
			result = std::string(minChars - result.length(), '0') + result;
		}
	}

	return result;
}
