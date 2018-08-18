#version 460

layout (location = 0) uniform float time;
layout (location = 1) uniform vec2 resolution;

in vec4 gl_FragCoord;

out vec4 out_Color;

const int MAX_STEPS = 255;
const float MIN_DIST = 0.01;
const float MAX_DIST = 100.0;
const float EPSILON = 0.0001;
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

float cube(vec3 p, vec3 pos, vec3 size)
{
	vec3 d = abs(p - pos) - size;

	float inside = min(max(d.x, max(d.y, d.z)), 0.0);
	float outside = length(max(d, 0.0));

	return inside + outside;
}

float scene(vec3 p)
{
	//float result = smin(sphere(p, vec3(-1, 0, 0), 1), sphere(p, vec3(1, 0, 0), 1), 0.75);

	float result = sphere(p, vec3(1, -0.8, 0), sin(time) * 0.1 + 0.4);
	result = unionSDF(result, sphere(p, vec3(-1, -0.8, 0), cos(time) * 0.1 + 0.5));
	result = unionSDF(result, sphere(p, vec3(0, 0.8, 0), 0.7));
	result = unionSDF(result, cube(p, vec3(0, -0.3, 0), vec3(0.3, 0.2, 0.1)));
	result = differenceSDF(result, cube(p, vec3(0, 0.0, 0), vec3(10, 10, 0.03))); // tha slicer
	result = unionSDF(result, sphere(repeatOP(p, vec3(5.1, 3.5, 5.1)), vec3(0, 0, 0), sin(time) * 0.1 + 0.59));
	return result;
}

float shortestDistToSurface(vec3 eye, vec3 marchingDir, float start, float end)
{
	float depth = start;
	for (int i = 0; i < MAX_STEPS; ++i)
	{
		float dist = scene(eye + depth * marchingDir);
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
	return normalize(vec3(
		scene(vec3(p.x + EPSILON, p.y, p.z)) - scene(vec3(p.x - EPSILON, p.y, p.z)),
        scene(vec3(p.x, p.y + EPSILON, p.z)) - scene(vec3(p.x, p.y - EPSILON, p.z)),
        scene(vec3(p.x, p.y, p.z  + EPSILON)) - scene(vec3(p.x, p.y, p.z - EPSILON))
		));
}

vec3 rayDir(float FOV, vec2 size, vec2 uv)
{
	vec2 xy = uv - size / 2.0;
	float z = size.y / tan(radians(FOV) / 2.0);
	return normalize(vec3(xy, -z));
}

vec3 Lighting(vec3 p, vec3 v)
{
	vec3 N = estimateNormal(p);
	vec3 L = normalize(vec3(sin(time * 0.5) * 0.5 + 0.5, -0.5, cos(time * 0.5) * 1.1));
	vec3 V = v;
	vec3 R = reflect(-L, N);

	float NoL = max(dot(N, -L), -0.5);
	NoL += (1 - NoL) * 0.375;
	vec3 diffuse = vec3(NoL, NoL, NoL);

	float RoV = max(dot(R, V), 0.0);
	RoV = pow(RoV, 20);
	vec3 specular = vec3(RoV, RoV, RoV);

	// Visualize normals:
	// return vec3(N * 0.5 + 0.5);

	return diffuse + specular;
}

void main() 
{
	vec3 dir = rayDir(45.0, resolution, gl_FragCoord.xy);
	float eyeDist = 10.5;
	float theta = time * 0.05;
#if 1
	mat4 eyeRotMat = mat4(
		cos(theta), 0, sin(theta), 0,
		0, 1, 0, 0,
		-sin(theta), 0, cos(theta), 0,
		0, 0, 0, 1);
	dir = vec3(eyeRotMat * vec4(dir, 0));
	vec3 eye = vec3(-sin(theta) * eyeDist, 0, cos(theta) * eyeDist);
#else
	vec3 eye = vec3(0, 0, 5);
#endif
	float dist = shortestDistToSurface(eye, dir, MIN_DIST, MAX_DIST);

	if (dist > MAX_DIST - EPSILON)
	{
		out_Color = vec4(0.08, 0.10, 0.12, 1);
		return;
	}

	vec4 ambient = vec4(0.02, 0.05, 0.05, 1.0);
	out_Color = vec4(Lighting(eye + dist * dir, dir), 1.0) * vec4(0.18, 0.45, 0.2, 1) + ambient;
}
