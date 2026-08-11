

# Skia-AliveGrid
A high-performance, custom-rendered FMX component for Delphi that provides a fluid, physics-based list interface. Built entirely on the Skia4Delphi graphics pipeline, it breaks away from traditional UI constraints to deliver a smooth, modern, and highly interactive user experience.     

Prototype v0.2     
     
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/LaMitaOne/Skia-AliveGrid)     
     
https://github.com/user-attachments/assets/e2952b0d-0a9c-4627-b30a-0976ce295234
      
<img width="360" height="202" alt="aymsoy" src="https://github.com/user-attachments/assets/c389ba5c-6bc1-459a-9690-52b368bcae6a" />
        
https://youtu.be/CmzZGL12WWs      
      
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

Latest changes:   
    v0.2:    
      - Scrolling Support: Added full vertical scrolling logic,    
        including mouse wheel interaction.    
      - Custom Scrollbar: Implemented a dynamic,    
        smoothly fading scrollbar button for visual scroll indication    
        and direct dragging.    
      - Virtualized Slide Pool: Added a dynamic pooling system that    
        recycles slides based on the current scroll offset to handle    
        large item lists efficiently.    
      - Smooth Scroll Physics: Integrated fast-snap logic for slides    
        during fast scrolling, pausing heavy physics calculations to    
        maintain high frame rates.    
    
 
