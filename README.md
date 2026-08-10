



# Skia-AliveGrid
A high-performance, custom-rendered FMX component for Delphi that provides a fluid, physics-based list interface. Built entirely on the Skia4Delphi graphics pipeline, it breaks away from traditional UI constraints to deliver a smooth, modern, and highly interactive user experience.     

Prototype v0.1     
     
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/LaMitaOne/Skia-AliveGrid)     
       
[<img width="576" height="856" alt="Unbenannt" src="https://github.com/user-attachments/assets/49ac92be-dc4b-4a6b-932a-bfa3d87bcbf3" />    
](https://github.com/user-attachments/assets/8d456986-18eb-4f93-b53a-1db8c1c9ed2b)  
    
✨ Key Features   
     -Real-Time Fluid Physics: The list items are not simple rectangles. They are constructed from a grid of interconnected particles using Verlet integration and constraint solving, creating a liquid, jelly-like wobble effect.     
     -Magnetic Control Dots: Each item features a magnetic indicator dot that snaps to the cursor when approached, providing tactile and intuitive feedback.      
     -Interactive Repulsion: Move your mouse over the grid, and the fluid items dynamically repel away from the cursor, settling smoothly back into place when the cursor leaves.     
     -Smooth Drag & Drop: Grab any item to drag it. The surrounding items fluidly swap positions to make room, and the dragged item snaps softly into its new slot upon release.     
     -Dynamic Intro & Outro Animations: New items organically flows up from the bottom of the screen into their correct positions and unfolds there to its final form. Removed items gracefully fall away.      
     -Optimized Rendering Pipeline:     
         Runs entirely on a separate background thread to keep the main UI thread at 0% load.     
         Uses a centralized ISkSurface caching system. Only dirty/changed regions are redrawn.     
         Achieves 0% CPU usage when idle.      
     -Flawless Resizing: Synchronized rendering prevents white screens, flickering, or crashes during window resizes. The fluid grid dynamically adds or removes particles to perfectly fit the new width in real-time.      
     -Media Support:     
         Load custom thumbnails for each item automatically.    
         KeepAspect (Letterbox) Cropping: Images are intelligently scaled to fit the thumbnail area without distortion, padding the edges smoothly.       
      -Integrated Text Caching for ultra-fast rendering of captions and file paths.     
      -1,8k lines so far…    
    
📦 Installation & Usage     
     
No manual code installation is required.     
Zipped exe and sample project included.     

