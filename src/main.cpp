
#include <string>

#include <windows.h>
#include <direct.h> // For _getcwd
#include <time.h> // For localtime

#include <glm/glm.hpp>
#include <glad/glad.h>
#include <glfw/glfw3.h>

#include "types.hpp"
#include "GLHelpers.hpp"
#include "Helpers.hpp"
#include "Logger.hpp"

void WINAPI glDebugOutput(GLenum source, GLenum type, GLuint id, GLenum severity,
	GLsizei length, const GLchar *message, const void *userParam);

void WindowSizeCallback(GLFWwindow* window, i32 newWidth, i32 newHeight);
void KeyCallback(GLFWwindow* window, int key, int scancode, int action, int mods);

std::string GetCurrentWorkingDirectory();
std::string GetDateString();

float g_SecondsElapsed = 0.0f;
float g_DeltaSeconds = 0.0f;
i32 g_FrameCount = 0;

i32 g_WindowWidth = 720;
i32 g_WindowHeight = 480;

bool g_bReloadShader = false;
bool g_bEnableVSync = true;

int main()
{
	GetConsoleHandle();

	std::string curWorkingDirStr(GetCurrentWorkingDirectory());

	if (glfwInit() == GLFW_FALSE)
	{
		PrintWarn("Failed to init glfw!\n");

		return -1;
	}

	glfwWindowHint(GLFW_CLIENT_API, GLFW_OPENGL_API);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
	GLFWwindow* window = glfwCreateWindow(g_WindowWidth, g_WindowHeight, "Beam Hiker", nullptr, nullptr);

	glfwSetWindowSizeCallback(window, WindowSizeCallback);
	glfwSetKeyCallback(window, KeyCallback);

	glfwMakeContextCurrent(window);

	gladLoadGLLoader((GLADloadproc)glfwGetProcAddress);

#if _DEBUG
	if (glDebugMessageCallback)
	{
		glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
		glDebugMessageCallback(glDebugOutput, nullptr);
		GLuint unusedIds = 0;
		glDebugMessageControl(GL_DONT_CARE,
			GL_DONT_CARE,
			GL_DONT_CARE,
			0,
			&unusedIds,
			true);
	}
#endif

	u32 program = glCreateProgram();
	glUseProgram(program);

	static const char* vertFilePath = "shaders/vert.v";
	static const char* fragFilePath = "shaders/frag.f";
	if (!LoadShaders(program, vertFilePath, fragFilePath))
	{
		PrintWarn("Failed to load shaders!\n");
		return -1;
	}

	// Setup directory watch
	DWORD dwWaitStatus;
	HANDLE dwChangeHandle;
	{
		std::string dir = curWorkingDirStr + "\\shaders\\";

		dwChangeHandle = FindFirstChangeNotification(
			dir.c_str(),
			FALSE,
			FILE_NOTIFY_CHANGE_LAST_WRITE);

		if (dwChangeHandle == INVALID_HANDLE_VALUE)
		{
			PrintError("ERROR: FindFirstChangeNotification function failed.\n");
		}
	}

	// Build full-screen quad
	u32 VAO;
	u32 VBO;
	{
		glGenVertexArrays(1, &VAO);
		glBindVertexArray(VAO);

		glGenBuffers(1, &VBO);
		glBindBuffer(GL_ARRAY_BUFFER, VBO);
		float quadVertexBuffer[] = {
			1.0f, 1.0f, 1.0f,
			1.0f, -1.0f, 1.0f,
			-1.0f, -1.0f, 1.0f,
			-1.0f, -1.0f, 1.0f,
			-1.0f, 1.0f, 1.0f,
			1.0f, 1.0f, 1.0f };
		glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertexBuffer), quadVertexBuffer, GL_STATIC_DRAW);

		i32 stride = sizeof(float) * 3;

		i32 location = 0;
		glEnableVertexAttribArray(location);
		glVertexAttribPointer((GLuint)location, 3, GL_FLOAT, GL_FALSE, stride, (void*)0);
		location += 4;
	}

	glViewport(0, 0, g_WindowWidth, g_WindowHeight);
	glDisable(GL_CULL_FACE);
	glDepthFunc(GL_ALWAYS);
	glDepthMask(GL_FALSE);

	if (g_bEnableVSync)
	{
		glfwSwapInterval(1);
	}

	float lastTime = (float)glfwGetTime();
	while (!glfwWindowShouldClose(window))
	{
		dwWaitStatus = WaitForSingleObject(dwChangeHandle, 0);
		switch (dwWaitStatus)
		{
		case WAIT_OBJECT_0:
			g_bReloadShader = true;

			if (FindNextChangeNotification(dwChangeHandle) == FALSE)
			{
				PrintError("Something bad happened?\n");
			}
		}

		if (g_bReloadShader)
		{
			g_bReloadShader = false;
			i32 newProgram = glCreateProgram();
			if (LoadShaders(newProgram, vertFilePath, fragFilePath))
			{
				glDeleteProgram(program);
				program = newProgram;

				std::string dateString = GetDateString();
				Print("Reloaded shaders  %s\n", dateString.c_str());
			}
			else
			{
				glDeleteProgram(newProgram);
				PrintError("Failed to reload shaders!\n");
			}
		}

		float currentTime = (float)glfwGetTime();
		g_DeltaSeconds = currentTime - lastTime;
		g_SecondsElapsed += g_DeltaSeconds;
		
		glUseProgram(program);

		glUniform1f(0, g_SecondsElapsed);
		glUniform2f(1, (float)g_WindowWidth, (float)g_WindowHeight);

		glDrawArrays(GL_TRIANGLES, 0, 6);

		if (g_FrameCount % 60 == 0)
		{
			std::string windowTitle("Beam hiker | " + std::to_string(g_DeltaSeconds*1000.0f) + "ms");
			glfwSetWindowTitle(window, windowTitle.c_str());
		}

		glfwSwapBuffers(window);
		glfwPollEvents();

		lastTime = currentTime;

		++g_FrameCount;
	}

	return 0;
}

void WINAPI glDebugOutput(GLenum source, GLenum type, GLuint id, GLenum severity, GLsizei length,
	const GLchar* message, const void* userParam)
{
	UNREFERENCED_PARAMETER(userParam);
	UNREFERENCED_PARAMETER(length);

	// Ignore insignificant error/warning codes
	if (id == 131169 || id == 131185 || id == 131218 || id == 131204)
	{
		return;
	}

	PrintError("---------------\n\t");
	PrintError("GL Debug message (%i): %s\n", id, message);

	switch (source)
	{
	case GL_DEBUG_SOURCE_API:             PrintError("Source: API"); break;
	case GL_DEBUG_SOURCE_WINDOW_SYSTEM:   PrintError("Source: Window System"); break;
	case GL_DEBUG_SOURCE_SHADER_COMPILER: PrintError("Source: Shader Compiler"); break;
	case GL_DEBUG_SOURCE_THIRD_PARTY:     PrintError("Source: Third Party"); break;
	case GL_DEBUG_SOURCE_APPLICATION:     PrintError("Source: Application"); break;
	case GL_DEBUG_SOURCE_OTHER:           PrintError("Source: Other"); break;
	}
	PrintError("\n\t");

	switch (type)
	{
	case GL_DEBUG_TYPE_ERROR:               PrintError("Type: Error"); break;
	case GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR: PrintError("Type: Deprecated Behaviour"); break;
	case GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR:  PrintError("Type: Undefined Behaviour"); break;
	case GL_DEBUG_TYPE_PORTABILITY:         PrintError("Type: Portability"); break;
	case GL_DEBUG_TYPE_PERFORMANCE:         PrintError("Type: Performance"); break;
	case GL_DEBUG_TYPE_MARKER:              PrintError("Type: Marker"); break;
	case GL_DEBUG_TYPE_PUSH_GROUP:          PrintError("Type: Push Group"); break;
	case GL_DEBUG_TYPE_POP_GROUP:           PrintError("Type: Pop Group"); break;
	case GL_DEBUG_TYPE_OTHER:               PrintError("Type: Other"); break;
	}
	PrintError("\n\t");

	switch (severity)
	{
	case GL_DEBUG_SEVERITY_HIGH:         PrintError("Severity: high"); break;
	case GL_DEBUG_SEVERITY_MEDIUM:       PrintError("Severity: medium"); break;
	case GL_DEBUG_SEVERITY_LOW:          PrintError("Severity: low"); break;
	case GL_DEBUG_SEVERITY_NOTIFICATION: PrintError("Severity: notification"); break;
	}
	PrintError("\n---------------\n");
}

void WindowSizeCallback(GLFWwindow* window, i32 newWidth, i32 newHeight)
{
	g_WindowWidth = newWidth;
	g_WindowHeight = newHeight;
	glViewport(0, 0, newWidth, newHeight);
}

void KeyCallback(GLFWwindow* window, int key, int scancode, int action, int mods)
{
	if (action == GLFW_PRESS)
	{
		if (key == GLFW_KEY_R)
		{
			g_bReloadShader = true;
		}
	}
}

std::string GetCurrentWorkingDirectory()
{
	const i32 MAX_BUF_LEN = 256;
	char currentWorkingDirectory[MAX_BUF_LEN];
	_getcwd(currentWorkingDirectory, MAX_BUF_LEN);
	return std::string(currentWorkingDirectory);
}

std::string GetDateString()
{
	struct tm newtime;

	__time64_t long_time;
	_time64(&long_time);
	if (_localtime64_s(&newtime, &long_time))
	{
		PrintError("Invalid argument to _localtime64_s.\n");
	}

	std::string result = IntToString(1900 + newtime.tm_year) + "-" + IntToString(newtime.tm_mon + 1, 2) + "-" + IntToString(newtime.tm_mday, 2) + " " +
		IntToString(newtime.tm_hour, 2) + ":" + IntToString(newtime.tm_min, 2) + "." + IntToString(newtime.tm_sec, 2);
	return result;
}
