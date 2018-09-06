
-- 
-- NOTES:
-- - DLLs should be built using the Multi-threaded Debug DLL flag (/MDd) in debug,
--   and the Multi-threade DLL flag (/MD) in release
-- 


solution "BeamHiker"
	configurations {
		"Debug",
		"Shipping"
	}

	platforms {
		"x32"
	}

	language "C++"

	location "../build/"
	objdir "../build/"


PROJECT_DIR = path.getabsolute("..")
SOURCE_DIR = PROJECT_DIR
DEPENDENCIES_DIR = path.join(SOURCE_DIR, "dependencies/")


-- Put intermediate files under build/Intermediate/config_platform/project
-- Put binaries under bin/config/project/platform --TODO: Really? confirm
-- TODO: Remove project cause we only have one
function outputDirectories(_project)
	local cfgs = configurations()
	local p = platforms()
	for i = 1, #cfgs do
		for j = 1, #p do
			configuration { cfgs[i], p[j] }
				targetdir("../bin/" .. cfgs[i] .. "_" .. p[j] .. "/" .. _project)
				objdir("../build/Intermediate/" .. cfgs[i]  .. "/" .. _project)		--seems like the platform will automatically be added
		end
	end
	configuration {}
end


function platformLibraries()
	local cfgs = configurations()
	for i = 1, #cfgs do
		local subdir = ""
		if (string.startswith(cfgs[i], "Debug"))
			then subdir = "Debug"
			else subdir = "Release"
		end
		configuration { "vs*", cfgs[i] }
			libdirs { 
				path.join(SOURCE_DIR, path.join("lib/", subdir))
			}
	end
	configuration {}
end

configuration "Debug"
	defines { "_DEBUG" }
	flags { "Symbols", "ExtraWarnings" }
configuration "Shipping"
	defines { "SHIPPING" }
	flags {"OptimizeSpeed", "No64BitChecks" }

configuration "vs*"
	flags { "NoIncrementalLink", "NoEditAndContinue" }
	linkoptions { "/ignore:4221" }
	defines { "PLATFORM_Win" }
	includedirs { 
		path.join(DEPENDENCIES_DIR, "include"),
		path.join(DEPENDENCIES_DIR, "glad/include"),
		path.join(DEPENDENCIES_DIR, "glfw/include"), 
		path.join(DEPENDENCIES_DIR, "glm")
	}
	debugdir "$(OutDir)"
configuration { "vs*", "x32" }
	flags { "EnableSSE2" }
	defines { "WIN32" }
configuration { "x32" }
	defines { "PLATFORM_x32" }
configuration {}


startproject "BeamHiker"

project "BeamHiker"
	kind "ConsoleApp"

	location "../build"

    defines { "_CONSOLE" }

	outputDirectories("BeamHiker")

	configuration "vs*"
		flags { "Winmain"}

		links { "opengl32" } 

	platformLibraries()

	--Linked libraries
    links { "opengl32", "glfw3" }

configuration {}

	--Additional includedirs
	includedirs { 
		path.join(SOURCE_DIR, "include"),
	}

	--Source files
    files {
		path.join(SOURCE_DIR, "include/**.h"), 
		path.join(SOURCE_DIR, "include/**.hpp"), 
		path.join(SOURCE_DIR, "src/**.cpp"),
		path.join(DEPENDENCIES_DIR, "glad/src/glad.c"),
	}

	-- Don't use pre-compiled header for the following files
	nopch {
		path.join(DEPENDENCIES_DIR, "glad/src/glad.c")
	}

	pchheader "stdafx.hpp"
	pchsource "../src/stdafx.cpp"




-- TODO: Figure out how to set stdafx.cpp to use /Yc compiler flag to generate precompiled header object
