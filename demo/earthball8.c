///////////////////////////////////////////////////////////////
// earthball8.c - physics example for lite-C pure mode
// lite-C version of the C++ SDK example in the manual
// (c) jcl / oP group 2010
///////////////////////////////////////////////////////////////
#include <default.c>
#include <ackphysx.h>

///////////////////////////////////////////////////////////////
// some global definitions 

PANEL* pSplash = { bmap = "logo_800.jpg"; }

TEXT* tHelp = { 
   pos_x = 10; pos_y = 10;
   font = "Arial#24bi";
   flags = SHADOW;
   string("Press [Space] to kick the blob!"); 
}

ENTITY* eBlob;

SOUND* sPong = "tap.wav";

VECTOR vSpeed, vAngularSpeed, vForce, vMove;
		
///////////////////////////////////////////////////////////////
// This is our event function for the ball impact.
function Plop()
{
// Play a ball impact sound.
	ent_playsound(eBlob,sPong,100);
}

// Function for kicking the ball in camera direction.
function Kick()
{
// Create a local speed vector
   VECTOR vKick;
// Use a horizontal and vertical speed to give the ball an upwards kick.	
   vKick.x = 150; vKick.y = 0; vKick.z = 75;
// Rotate it in camera direction.   
	vec_rotate(vKick,camera.pan);
// Now apply the speed to the ball, and play a hit sound.
	pXent_addvelcentral(eBlob,vKick);
	Plop();
}

///////////////////////////////////////////////////////////////
// If a function is named "main", it's automatically started
function main()
{
// Activate 800x600 screen resolution and stencil shadows,
// and set the sound at full volume.
// Video_mode and video_aspect can be set 
// before initializig the video device during the first wait().
  video_mode = 7;
  video_aspect = 4./3.; // 4:3 monitor for 800x600
	shadow_stencil = 3;
	d3d_antialias = 4;
	sound_vol = 100;
	physX_open();	// use physics

// Make the splash screen visible.
	set(pSplash,SHOW);

// After a panel is set to SHOW, we have to wait 3 frames
// until we can really see it on the screen.
// The first frame paints it into the background buffer,
// two more frames are needed until the background buffer
// is flipped to the front in a triple buffer system.
	wait(3);

// Before we can create level entities, a level must be loaded.
	level_load("small.hmp");

	// create a sky cube on layer 0
	ENTITY* sky = ent_createlayer("skycube+6.dds", SKY | CUBE | SHOW, 0);
// lift the sky and the camera to get a better overview	
	sky.z = 30;
	camera.z = 30;

// Let's now create a ball at position (0,0,100).
// The vector function converts 3 floats to a temporary var vector
// for passing positions to engine functions.
	eBlob = ent_create("blob.mdl",vector(0,0,100),NULL);
// Set an entity flag to cast a dynamic shadow
	set(eBlob,SHADOW);
// Use one of the default materials for giving it a shiny look
	eBlob.material = mat_metal;

// Now let's set the blob's physical properties. 
	pXent_settype(eBlob,PH_RIGID,PH_CAPSULE);
	pXent_setelasticity(eBlob,80);
	pXent_setdamping(eBlob,20,5);

// We add a small speed to give it a little sidewards kick. 
	pXent_addvelcentral(eBlob,vector(10,20,0));

// Activate an event: if the blob hits something, a sound shall be played. 
// We set the event function and the collision flag for triggering 
// EVENT_FRICTION event at collisions with the level. 
	pXent_setcollisionflag(eBlob,NULL,NX_NOTIFY_ON_START_TOUCH);
	eBlob.event = Plop;
	
// Remove the splash screen and display the text.
	pan_remove(pSplash);
	set(tHelp,SHOW);

// We want to kick the ball by hitting the [Space] key.
// Assign the 'Kick' function to the on_space event.
	on_space = Kick;

// play the sound as if someone had kicked the ball into play
	Plop();

// During the main loop we're just moving the camera
	while (1) 
	{
// For the camera movement we use the 
// vec_accelerate() function. It accelerates a speed and
// is not dependent on the frame rate - so we don't need to
// limit the fps in this example. This code is equivalent
// to the built-in camera movement, but uses different keys.
		vForce.x = -5*(key_force.x + mouse_force.x);	// pan angle
		vForce.y = 5*(key_force.y + mouse_force.y);	// tilt angle
		vForce.z = 0;	// roll angle
		vec_accelerate(vMove,vAngularSpeed,vForce,0.8);
		vec_add(camera.pan,vMove);		

		vForce.x = 6 * (key_w - key_s);		// forward
		vForce.y = 6 * (key_a - key_d);		// sideward
		vForce.z = 6 * (key_home - key_end);	// upward
		vec_accelerate(vMove,vSpeed,vForce,0.5);
		vec_rotate(vMove,camera.pan);
		vec_add(camera.x,vMove);
		wait(1);
	}

// We don't need to free our created entities, bitmaps and sounds. 
// The engine does this automatically when closing.
}
