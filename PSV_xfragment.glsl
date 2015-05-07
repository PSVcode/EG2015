/*
	This code is released under the BSD license. Although not required, we 
	appreciate hearing (frederic.mora@unilim.fr) if you use this for a commercial
	or academic purpose, since that justifies the effort of making it available.

	Copyright (c) 2014, Julien Gerhards and Frédéric Mora
	All rights reserved.
	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions are met:

	* Redistributions of source code must retain the above copyright
	  notice, this list of conditions and the following disclaimer.
	* Redistributions in binary form must reproduce the above copyright
	  notice, this list of conditions and the following disclaimer in the
	  documentation and/or other materials provided with the distribution.
	* Neither the name of the University of California, Berkeley nor the
	  names of its contributors may be used to endorse or promote products
	  derived from this software without specific prior written permission.

	THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND ANY
	EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
	DISCLAIMED. IN NO EVENT SHALL THE REGENTS AND CONTRIBUTORS BE LIABLE FOR ANY
	DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
	(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
	ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
	SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/

/*
	Partitioned Shadow Volumes

	-- Shading with a TOP tree --

	This is the modified fragment shader implementation to render xray shadows as described in the Eurographics 2015 paper:
	Partitioned Shadow Volumes, by Julien Gerhards, Frédéric Mora, Lilian Aveneau and Djamchid Ghazanfarpour
	@inproceedings{PSV2015,
 		author = {Gerhards Julien and Mora Frédéric and Aveneau Lilian and Djamchid Ghazanfarpour}
 		title = {Partitioned Shadow Volumes},
 		booktitle = {Computer Graphics Forum, special issue of Eurographics 2015 conference}
 		volume = {34},
 		number = {2},
 		year = {2015},
	    location = {Zurich},
	    doi = {10.1111/cgf.12583}
	} 

	Please, have a look at the comments to know how to use this shader

	All the comments "TO COMPLETE" must be replaced with few lines of code depending on your own application

*/
#version 430

// Deferred Buffer: Must contain the fragment position in the world coordinates system
layout( binding = 0) uniform sampler2DArray deferredBuffer;

// Texture coordinate to read in the deferred buffer
in vec3 texCoord;

// fragment final color
layout (location = 0) out vec4 color;

// a TOP tree node
struct node {
	vec4 plane;
	uint link[4]; /* 0: positive child, 1: intersection child, 2: negative child (not used), 3: wedge angle */
};

// TOP tree buffer
layout (std430, binding=13) readonly buffer TOPTree {
	node nodes[];
};

// Buffer to read the root index
layout (std430, binding=29) readonly buffer TOPTreeRoot	{
	uint root;
};

// return a value between 0 (opaque) and 1 (fully transparent) according to the direction to the light and the surface normal
float TOPTREE_xquery( in vec3 p, in vec3 normal){ 
    uint stack[64]; // bigger stack, more nodes to visit
	uint current, stacksize = 0;
	const float sqdist = dot(p,p); // squared distance from p to the origin (the light)

	stack[ stacksize++ ] =  root; // push the root
	float res = 1.0; // result initialized to fully transparent


	while(stacksize>0){

		// pop
		current = stack[ --stacksize ];
		const node n = nodes[ current ];
	
		float offset = dot(n.plane, vec4(p,1));
		
	
		// If the current plane is a capping plane
		if ( current%4==3 ) // thus p is already inside the 3 shadow planes of the related SV. 
		{
			// if p is in front of the triangle casting the SV
			if ( offset>0.0 ) 
			{
				// continue to the positive child if it exists
				if ( n.link[0]>0 )
					stack[ stacksize++ ] = n.link[0];
			}
			else{ // p is inside the SV
				// since the triangle is not opaque, we need to check all the children if they exist !
				if ( n.link[0]>0 ) // pos child
					stack[ stacksize++ ] = n.link[0];
				if ( n.link[1]>0 ) // inter child (useful only if your model has triangles intersecting each other)
					stack[ stacksize++ ] = n.link[1];
				if ( n.link[2]>0 ) // neg child
					stack[ stacksize++ ] = n.link[2];
			
				// compute pseudo visibility attenuation taking into account the angle between light ray to p and the triangle
				float alpha = dot( normalize(p) , n.plane.xyz );
				res -= 0.2*(1.0-abs(alpha));
				// (You may want to compute something more realist here !)
			}		
		}
		else // the current plane is a shadow plane
		{
			// push intersection child if it exists and if p is in the wedge
			if ( n.link[1]>0  && offset*offset / sqdist < uintBitsToFloat(n.link[3]) )
				stack[ stacksize++ ] = n.link[1];
		
			// positive case
			if ( offset>0.0){
				// continue to the positive child if it exists
				if ( n.link[0]>uint(0) ) 
					stack[ stacksize++ ] = n.link[0];
			}
			else{ // continue to the negative child (which always exists for nodes containing a shadow plane !)
				 stack[ stacksize++ ] = current+1;
			}
		}
	}
	// no more nodes to visit
	return res;
}


// must return the fragment position in the world space coordinates system
vec4 getFragmentPosition(){
	// coordinates should not be interpolated !
	return textureLod(deferredBuffer, /* TO COMPLETE */);
}

// must return the fragment normal in the world coordinates system
vec3 getFragmentNormal(){
	return normalize( textureLod( deferredBuffer, /* TO COMPLETE */).xyz);
}

// return true if a fragment exists, otherwise false (no projected geometry)
bool fragmentExist( in vec4 frag ){
	// TO COMPLETE
}

// must return the light position in the world space coordinates system
vec3 getLight(){
	// TO COMPLETE
}

void main()
{	
	vec4 pos = getFragmentPosition();
	if( fragmentExist(pos)==true )
	{
		vec3 normal = getFragmentNormal();
		vec3 light = getLight();
		float visibility = TOPTREE_xquery(pos.xyz-light, normal); 
		
		/* You may want compute the final color using visiblity (0/1), light, normal and pos ! Or whatever you want.
		color = TO COMPLETE
		*/
		
	}
	else
		color=vec4(1);
}
	
