////////////////////////////////////////////////////////////////////////////
// small.c - small lite-C example
////////////////////////////////////////////////////////////////////////////

function main()
{
	// Load the terrain named "small.hmp"
	level_load("small.hmp"); 
	// Now create the "earth.mdl" model at x = 10, y = 20, z = 30 in our 3D world
	ent_create("earth.mdl", vector(10, 20, 30), NULL);
	// NULL tells the engine that the model doesn't have to do anything
}