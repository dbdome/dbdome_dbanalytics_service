// Server Form Functionality
(function() {
    const serverForm = document.getElementById('serverForm');
    const submitBtn = document.querySelector('.submit-btn');
    const sparklesContainer = document.getElementById('sparklesContainer');
    const successMessage = document.getElementById('successMessage');
    
    // Create sparkles animation from entire form
    function createSparkles(element, colorSet, count) {
        if (!sparklesContainer || !element) return;
        
        const rect = element.getBoundingClientRect();
        const particleCount = count || 80;
        const colors = colorSet && colorSet.length ? colorSet : ['blue', 'cyan', 'white'];
        
        for (let i = 0; i < particleCount; i++) {
            const sparkle = document.createElement('div');
            sparkle.className = 'sparkle';
            
            // Random color from provided set
            const colorIndex = Math.floor(Math.random() * colors.length);
            const color = colors[colorIndex];
            sparkle.classList.add(`sparkle-${color}`);
            
            // Generate particles from entire form area
            let startX, startY;
            const particleType = Math.random();
            
            if (particleType < 0.5) {
                // 50% from edges
                const side = Math.floor(Math.random() * 4);
                switch(side) {
                    case 0: // Top edge
                        startX = rect.left + Math.random() * rect.width;
                        startY = rect.top;
                        break;
                    case 1: // Right edge
                        startX = rect.right;
                        startY = rect.top + Math.random() * rect.height;
                        break;
                    case 2: // Bottom edge
                        startX = rect.left + Math.random() * rect.width;
                        startY = rect.bottom;
                        break;
                    case 3: // Left edge
                        startX = rect.left;
                        startY = rect.top + Math.random() * rect.height;
                        break;
                }
            } else {
                // 50% from interior
                startX = rect.left + Math.random() * rect.width;
                startY = rect.top + Math.random() * rect.height;
            }
            
            // Horizontal drift for natural movement (increased for more spread)
            const driftX = (Math.random() - 0.5) * 200;
            sparkle.style.setProperty('--drift-x', driftX + 'px');
            
            // Random size
            const size = 3 + Math.random() * 4;
            sparkle.style.width = size + 'px';
            sparkle.style.height = size + 'px';
            
            // Animation duration (2-3.5 seconds for smooth upward rise)
            const duration = 2 + Math.random() * 1.5;
            sparkle.style.animationDuration = duration + 's';
            
            // Staggered delay for natural appearance
            const delay = Math.random() * 0.3;
            sparkle.style.animationDelay = delay + 's';
            
            // Position sparkle
            sparkle.style.left = startX + 'px';
            sparkle.style.top = startY + 'px';
            
            sparklesContainer.appendChild(sparkle);
            
            // Remove sparkle after animation
            setTimeout(function() {
                if (sparkle.parentNode) {
                    sparkle.parentNode.removeChild(sparkle);
                }
            }, (duration + delay) * 1000);
        }
    }
    
    // Show success message
    function showSuccessMessage() {
        if (successMessage) {
            successMessage.classList.remove('hide');
            successMessage.classList.add('show');
            
            // Hide message after 3 seconds
            setTimeout(function() {
                successMessage.classList.remove('show');
                successMessage.classList.add('hide');
            }, 3000);
        }
    }
    
    // Handle form submission
    if (serverForm && submitBtn) {
        serverForm.addEventListener('submit', function(e) {
            e.preventDefault();
            
            // Validate form
            if (serverForm.checkValidity()) {
                // Start form fade-out animation
                serverForm.classList.add('fade-out');
                
                // Create cyan, white, and blue sparks from entire form
                createSparkles(serverForm, ['cyan', 'white', 'blue'], 80);
                
                // Show success message after form fades out
                setTimeout(function() {
                    showSuccessMessage();
                }, 1200);
                
                // Reset form after animation completes
                setTimeout(function() {
                    serverForm.classList.remove('fade-out');
                    serverForm.reset();
                }, 2000);
            } else {
                serverForm.reportValidity();
            }
        });
    }
})();

