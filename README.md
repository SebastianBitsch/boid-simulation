# Boid-Simulation

A simple 2D boid simulation implemented in the Godot engine.  
Flock mates - nearest neighbouring boids - are found using a quadtree structure for search, which improves the performance over linear search.  
Runs at 60fps for up to 1500 boids in a 2000x2000 grid at it's current state. The simulation is however still very unoptimized. e.g. every calculation is performed for every boid at every frame, and no results are cached.

Features yet to be implemented include predator avoidance, leader boids and goal steering

**Video demo**  
https://www.youtube.com/watch?v=Yl7w26nBwUc&t=1s. 

**Sources**  
http://www.red3d.com/cwr/boids/  
http://www.kfish.org/boids/pseudocode.html  
https://en.wikipedia.org/wiki/Quadtree  

