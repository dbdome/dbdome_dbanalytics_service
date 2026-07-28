document.addEventListener('DOMContentLoaded', function() {
    const form = document.getElementById('customForm');
    const successMessage = document.getElementById('successMessage');
    const canvas = document.getElementById('confettiCanvas');
    const ctx = canvas.getContext('2d');
    
    // Set canvas size
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
    
    // Resize canvas on window resize
    window.addEventListener('resize', function() {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
    });
    
    // Confetti particles array
    let particles = [];
    let animationId = null;
    
    // Confetti colors: white, teal, and glowing peach-orange
    const colors = ['white', '#20B2AA', '#FF8C42']; // white, teal, glowing peach-orange
    
    // Create confetti particle with enhanced properties
    function createParticle(x, y) {
        return {
            x: x,
            y: y,
            vx: (Math.random() - 0.5) * 6,
            vy: -Math.random() * 4 - 3,
            size: Math.random() * 6 + 3,
            color: colors[Math.floor(Math.random() * colors.length)],
            rotation: Math.random() * Math.PI * 2,
            rotationSpeed: (Math.random() - 0.5) * 0.3,
            life: 1.0,
            fadeSpeed: 0.008 + Math.random() * 0.004,
            floatSpeed: -0.5 - Math.random() * 0.5
        };
    }
    
    // Animate confetti with enhanced glowing effects
    function animateConfetti() {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        
        // Update and draw particles
        for (let i = particles.length - 1; i >= 0; i--) {
            const particle = particles[i];
            
            // Update position with upward float effect
            particle.x += particle.vx * 0.8; // Slow down horizontal movement
            particle.y += particle.vy;
            particle.vy += 0.05; // Reduced gravity for slower fall
            particle.vy += particle.floatSpeed * 0.1; // Upward float
            particle.rotation += particle.rotationSpeed;
            particle.life -= particle.fadeSpeed; // Custom fade speed
            
            // Draw particle with enhanced glowing effect
            ctx.save();
            ctx.globalAlpha = particle.life;
            ctx.translate(particle.x, particle.y);
            ctx.rotate(particle.rotation);
            
            // Enhanced glow effect for glowing colors
            ctx.shadowBlur = 20;
            ctx.shadowColor = particle.color;
            ctx.fillStyle = particle.color;
            
            // Draw sparkle shape (diamond/star shape for more magical effect)
            ctx.beginPath();
            ctx.moveTo(0, -particle.size / 2);
            ctx.lineTo(particle.size / 3, 0);
            ctx.lineTo(0, particle.size / 2);
            ctx.lineTo(-particle.size / 3, 0);
            ctx.closePath();
            ctx.fill();
            
            // Add center dot for extra brightness and glow
            ctx.beginPath();
            ctx.arc(0, 0, particle.size / 4, 0, Math.PI * 2);
            ctx.fill();
            
            // Add outer glow ring for extra glowing effect
            ctx.shadowBlur = 15;
            ctx.beginPath();
            ctx.arc(0, 0, particle.size / 2, 0, Math.PI * 2);
            ctx.fill();
            
            ctx.restore();
            
            // Remove dead particles
            if (particle.life <= 0 || particle.y < -50 || particle.y > canvas.height + 50) {
                particles.splice(i, 1);
            }
        }
        
        // Continue animation if particles exist
        if (particles.length > 0) {
            animationId = requestAnimationFrame(animateConfetti);
        } else {
            animationId = null;
        }
    }
    
    // Trigger enhanced confetti burst
    function burstConfetti(buttonX, buttonY) {
        // Clear any existing animation
        if (animationId) {
            cancelAnimationFrame(animationId);
        }
        
        particles = [];
        // Significantly increased particle count for more abundance
        const particleCount = 600;
        
        // Create multiple bursts for more density
        for (let i = 0; i < particleCount; i++) {
            // Add some randomness to origin for wider spread
            const offsetX = (Math.random() - 0.5) * 40;
            const offsetY = (Math.random() - 0.5) * 40;
            particles.push(createParticle(buttonX + offsetX, buttonY + offsetY));
        }
        
        animateConfetti();
    }
    
    // Form submission
    form.addEventListener('submit', function(e) {
        e.preventDefault();
        
        // Get button position for confetti origin
        const button = form.querySelector('.submit-btn');
        const buttonRect = button.getBoundingClientRect();
        const buttonX = buttonRect.left + buttonRect.width / 2;
        const buttonY = buttonRect.top + buttonRect.height / 2;
        
        // Trigger enhanced confetti animation immediately
        burstConfetti(buttonX, buttonY);
        
        // Trigger form exit animation (fade out + move upward)
        form.classList.add('exit');
        
        // Show success message after form has started fading
        setTimeout(function() {
            successMessage.classList.add('show');
            
            // Hide success message after 3 seconds
            setTimeout(function() {
                successMessage.classList.remove('show');
            }, 3000);
        }, 1000);
    });
});

