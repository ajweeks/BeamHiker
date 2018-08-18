#version 460

layout (location = 0) uniform float time;
layout (location = 1) uniform vec2 resolution;

in vec4 gl_FragCoord;

out vec4 color;

const int MAX_STEPS = 500;
const float MIN_DIST = 1;
const float MAX_DIST = 250.0;
const float EPSILON = 0.001;
const float PI = 3.14159265359;

float intersectSDF(float A, float B)
{
	return max(A, B);
}

float unionSDF(float A, float B)
{
	return min(A, B);
}

float differenceSDF(float A, float B)
{
	return max(A, -B);
}

// polynomial smooth min (k = 0.1);
float smin(float a, float b, float k)
{
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

mat3 rotateXOP(float theta)
{
	float c = cos(theta);
	float s = sin(theta);
	return mat3(
		vec3(1, 0, 0),
		vec3(0, c, -s),
		vec3(0, s, c)
	);
}

mat3 rotateYOP(float theta)
{
	float c = cos(theta);
	float s = sin(theta);
	return mat3(
		vec3(c, 0, s),
		vec3(0, 1, 0),
		vec3(-s, 0, c)
	);
}

mat3 rotateZOP(float theta)
{
	float c = cos(theta);
	float s = sin(theta);
	return mat3(
		vec3(c, -s, 0),
		vec3(s, c, 0),
		vec3(0, 0, 1)
	);
}

vec3 repeatOP(vec3 p, vec3 c)
{
	return mod(p, c) - 0.5 * c;
}

// float blendOP(vec3 p)
// {
// 	float d1 = primitiveA(p);
//     float d2 = primitiveB(p);
//     return smin(d1, d2);
// }

float sphere(vec3 p, vec3 pos, float r)
{
	return length(p - pos) - r;
}

float plane(vec3 p, vec3 pos, vec4 n)
{
	return dot(p - pos, n.xyz) + n.w;
}

float box(vec3 p, vec3 pos, vec3 size)
{
	// Doesn't work with differenceSDF?:
	//return length(max(abs(p - pos) - size, 0.0));

	vec3 d = abs(p - pos) - size;

	float inside = min(max(d.x, max(d.y, d.z)), 0.0);
	float outside = length(max(d, 0.0));

	return inside + outside;

}

float boxRound(vec3 p, vec3 pos, vec3 size, float r)
{
	return length(max(abs(p - pos) - size, 0.0)) - r;
}

float cylinderX(vec3 p, vec3 c)
{
	return length(p.yz - c.xz) - c.y;
}

float cylinderY(vec3 p, vec3 c)
{
	return length(p.xz - c.xy) - c.z;
}

float cylinderZ(vec3 p, vec3 c)
{
	return length(p.xy - c.xz) - c.x;
}

float torus(vec3 p, vec3 pos, vec2 t)
{
	p -= pos;
	vec2 q = vec2(length(p.xz) - t.x, p.y);
	return length(q) - t.y;
}

float map(vec3 p)
{
	//float result = smin(sphere(p, vec3(-1, 0, 0), 1), sphere(p, vec3(1, 0, 0), 1), 0.75);

// Sphere matrix
#if 0
	float result = sphere(p, vec3(1, -0.8, 0), sin(time) * 0.1 + 0.4);
	result = unionSDF(result, sphere(p, vec3(-1, -0.8, 0), cos(time) * 0.1 + 0.5));
	float roundness = 0.05;
	result = unionSDF(result, sphere(p, vec3(0, 0.8, 0), 0.7));
	//result = smin(unionSDF(result, boxRound(p, vec3(0, -0.6, 0), vec3(0.3, 0.2, 0.1), roundness)),
	//	unionSDF(result, boxRound(p, vec3(0, -0.2, 0), vec3(0.3, 0.2, 0.1), roundness)), 0.1);
	result = differenceSDF(result, boxRound(p, vec3(0, 0, 0), vec3(10, 10, 0.05), 0.005)); // tha slicer
	result = unionSDF(result, plane(p, vec3(0, -1.5, 0), normalize(vec4(0, 1, 0, 1))));
	mat3 rot = rotateZOP(-time * 0.035);
	rot *= rotateXOP(-sin(time) * 0.05);
	vec3 rotP = rot * p;
	float s = sin(time) * 0.1 + 0.9;
	// spheresresult = unionSDF(result, sphere(repeatOP(rotP * s, vec3(5.1, 3.5, 5.1)) / s, vec3(0, 0, 0), sin(time) * 0.1 + 0.59));
	result = unionSDF(result, torus(p, vec3(0, (sin(time * 3) * 0.2 + 0.8) - 2.5, 0), vec2(2.5, 0.5)));
#else // Arch
	float result = plane(p, vec3(0, -1, 0), normalize(vec4(0, 1, 0, 1)));

	float arch = box(p, vec3(0, -1, 0),vec3(1.2, 2, 0.4));
	arch = differenceSDF(arch, cylinderZ(p - vec3(-1, -1, 0), vec3(1, 0, 0.5)));
	arch = differenceSDF(arch, box(p, vec3(0, -1.25, 0), vec3(1, 0.75, 1)));
	arch = intersectSDF(arch, 
		unionSDF(cylinderZ(p - vec3(-1.2, -1.4, 0), vec3(1.2, 1, 1)), box(p, vec3(0, -1, 0), vec3(2, 1, 1))));

	result = unionSDF(result, arch);
#endif

	return result;
}

float computeSoftShadow(vec3 rayStart, vec3 rayDir, float minT, float maxT)
{
	float res = 1.0;
	float t = minT;
	float ph = 1e10;

	for (int i = 0; i < 32; i++)
	{
		float h = map(rayStart + t * rayDir);
		float y = h * h / (2.0 * ph);
		float d = sqrt(h * h - y * y);
		res = min(res, 10.0 * d / max(t - y, 0.0));
		ph = h;

		t += h;

		if (res < 0.0001 || t > maxT)
		{
			break;
		}
	}

	return clamp(res, 0.0, 1.0);
}

float shortestDistToSurface(vec3 eye, vec3 marchingDir, float start, float end, inout int steps)
{
	float depth = start;
	for (steps = 0; steps < MAX_STEPS; ++steps)
	{
		float dist = map(eye + depth * marchingDir);
		if (dist < EPSILON)
		{
			return depth;
		}
		depth += dist;
		if (depth >= end)
		{
			return end;
		}
	}

	return end;
}

vec3 estimateNormal(vec3 p)
{
	// return normalize(vec3(
	// 	map(vec3(p.x + EPSILON, p.y, p.z)) - map(vec3(p.x - EPSILON, p.y, p.z)),
 	//  map(vec3(p.x, p.y + EPSILON, p.z)) - map(vec3(p.x, p.y - EPSILON, p.z)),
 	//  map(vec3(p.x, p.y, p.z  + EPSILON)) - map(vec3(p.x, p.y, p.z - EPSILON))
	// 	));

	vec2 e = vec2(1.0, -1.0) * 0.5773 * 0.0005;
	return normalize(e.xyy * map(p + e.xyy) +
					e.yyx * map(p + e.yyx) + 
					e.yxy * map(p + e.yxy) + 
					e.xxx * map(p + e.xxx));
}

vec3 rayDir(float FOV, vec2 size, vec2 uv)
{
	vec2 xy = uv - size / 2.0;
	float z = size.y / tan(radians(FOV) / 2.0);
	return normalize(vec3(xy, -z));
}

vec3 Lighting(vec3 rayStart, float dist, vec3 rayDir)
{
	vec3 p = rayStart + dist * rayDir;

	vec3 N = estimateNormal(p);
	vec3 L = normalize(vec3(-0.5, -0.5, -1.1));
	//vec3 L = normalize(vec3(sin(time * 0.5) * 0.5 + 0.5, -0.5, cos(time * 0.5) * 1.1));
	vec3 V = rayDir;
	vec3 R = reflect(-L, N);

	float NoL = max(dot(N, -L), -0.5);
	NoL += (1 - NoL) * 0.375;
	vec3 diffuse = vec3(NoL, NoL, NoL);

	float RoV = max(dot(R, V), 0.0);
	RoV = pow(RoV, 20);
	vec3 specular = vec3(RoV, RoV, RoV);

	vec3 lightPos = vec3(-5, -5, -5);
	float shadow = computeSoftShadow(p, -L, 0.0001, 5.0);

	L = -L;
	R = reflect(-L, N);

	NoL = max(dot(N, -L), -0.5);
	NoL += (1 - NoL) * 0.375;
	diffuse += vec3(NoL, NoL, NoL) * 0.5;

	RoV = max(dot(R, V), 0.0);
	RoV = pow(RoV, 20);
	specular += vec3(RoV, RoV, RoV) * 0.5;

	float AO = 0;

	int aoSteps = 6;
	float aoDist = 0.5;
	for (int i = 0; i <aoSteps; i++)
	{
		float s = map(p + (i / float(aoSteps)) * aoDist * N);
		AO += s / aoDist;
	}
	AO = clamp(AO, 0, 1);

	// Visualize normals:
	// return vec3(N * 0.5 + 0.5);


	return diffuse * shadow * AO + specular;
}

float random1f(vec2 seed)
{
    return fract(sin(dot(seed.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

vec2 random2f(float seed)
{
	vec2 seed2 = vec2(time * 0.95, time * 1.1) * seed;
	return vec2(random1f(seed2), random1f(seed2));
}

vec3 rendererCalculateColor(vec3 rayStart, vec3 rayDir)
{
	vec3 color;

	int steps = 0;
	float dist = shortestDistToSurface(rayStart, rayDir, MIN_DIST, MAX_DIST, steps);

// Display performance
#if 0
	color = vec3(float(steps) / MAX_STEPS, 0, 0);
	return color;
#endif

	if (dist > MAX_DIST - EPSILON)
	{
		color = vec3(0.08, 0.10, 0.12);
		return color;
	}

	vec3 ambient = vec3(0.002, 0.005, 0.005);
	// Color by uv: * vec4(gl_FragCoord.xy/resolution * 0.9 + 0.1, 1, 1)
	color = Lighting(rayStart, dist, rayDir) * vec3(0.08, 0.35, 0.1) + ambient;

	return color;
}

vec3 calculatePixelColor(vec2 pixel)
{
	vec3 color = vec3(0, 0, 0);

	int pathsPerPixel = 4;
	for (int i = 0; i < pathsPerPixel; i++)
	{
		vec3 rayDir = rayDir(45.0, resolution, pixel + random2f(i * 13.25165) * 0.5);
		float eyeDist = 14;
		float theta = time * 0.25;

	#if 1
		mat4 eyeRotMat = mat4(
			cos(theta), 0, sin(theta), 0,
			0, 1, 0, 0,
			-sin(theta), 0, cos(theta), 0,
			0, 0, 0, 1);
		rayDir = vec3(eyeRotMat * vec4(rayDir, 0));
		vec3 rayStart = vec3(-sin(theta) * eyeDist, 0, cos(theta) * eyeDist);
	#else
		vec3 rayStart = vec3(0, 0, 5);
	#endif

		color += rendererCalculateColor(rayStart, rayDir);
	}
	color /= float(pathsPerPixel);

	color.rgb = color.rgb / (color.rgb + vec3(1.0f)); // Reinhard tone-mapping
	color.rgb = pow(color.rgb, vec3(0.45)); // Gamma correction (1.0/2.2)

	return color;
}

void main() 
{
	color = vec4(calculatePixelColor(gl_FragCoord.xy), 1);
}
