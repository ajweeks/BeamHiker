#include "stdafx.hpp"

#include "GLHelpers.hpp"

#include <glad/glad.h>

#include <string>

#include "Helpers.hpp"
#include "Logger.hpp"

bool LoadShaders(u32 program, const char* vertFilePath, const char* fragFilePath)
{
	bool bSuccess = true;

	GLuint vertexShaderID = glCreateShader(GL_VERTEX_SHADER);
	GLuint fragmentShaderID = glCreateShader(GL_FRAGMENT_SHADER);

	std::vector<char> vertexShaderCode;
	if (!ReadFile(vertFilePath, vertexShaderCode, false))
	{
		PrintError("Could not find vertex shader: %s\n", vertFilePath);
	}
	vertexShaderCode.push_back('\0'); // Signal end of string with terminator character

	std::vector<char> fragmentShaderCode;
	if (!ReadFile(fragFilePath, fragmentShaderCode, false))
	{
		PrintError("Could not find fragment shader: %s\n", fragFilePath);
	}
	fragmentShaderCode.push_back('\0'); // Signal end of string with terminator character

	GLint result = GL_FALSE;
	i32 infoLogLength;

	// Compile vertex shader
	char const* vertexSourcePointer = vertexShaderCode.data(); // TODO: Test
	glShaderSource(vertexShaderID, 1, &vertexSourcePointer, NULL);
	glCompileShader(vertexShaderID);

	glGetShaderiv(vertexShaderID, GL_COMPILE_STATUS, &result);
	if (result == GL_FALSE)
	{
		glGetShaderiv(vertexShaderID, GL_INFO_LOG_LENGTH, &infoLogLength);
		std::string vertexShaderErrorMessage;
		vertexShaderErrorMessage.resize((size_t)infoLogLength);
		glGetShaderInfoLog(vertexShaderID, infoLogLength, NULL, (GLchar*)vertexShaderErrorMessage.data());
		PrintError("%s\n", vertexShaderErrorMessage.c_str());
		bSuccess = false;
	}

	// Compile fragment shader
	char const* fragmentSourcePointer = fragmentShaderCode.data();
	glShaderSource(fragmentShaderID, 1, &fragmentSourcePointer, NULL);
	glCompileShader(fragmentShaderID);

	glGetShaderiv(fragmentShaderID, GL_COMPILE_STATUS, &result);
	if (result == GL_FALSE)
	{
		glGetShaderiv(fragmentShaderID, GL_INFO_LOG_LENGTH, &infoLogLength);
		std::string fragmentShaderErrorMessage;
		fragmentShaderErrorMessage.resize((size_t)infoLogLength);
		glGetShaderInfoLog(fragmentShaderID, infoLogLength, NULL, (GLchar*)fragmentShaderErrorMessage.data());
		PrintError("%s\n", fragmentShaderErrorMessage.c_str());
		bSuccess = false;
	}

	glAttachShader(program, vertexShaderID);
	glAttachShader(program, fragmentShaderID);
	
	glLinkProgram(program);

	GLint linkResult = GL_FALSE;
	glGetProgramiv(program, GL_LINK_STATUS, &linkResult);
	if (linkResult == GL_FALSE)
	{
		PrintError("Failed to link program!\n");
		bSuccess = false;
	}

	return bSuccess;
}

bool LinkProgram(u32 program)
{
	glLinkProgram(program);

	GLint result = GL_FALSE;
	glGetProgramiv(program, GL_LINK_STATUS, &result);
	if (result == GL_FALSE)
	{
		return false;
	}

	return true;
}