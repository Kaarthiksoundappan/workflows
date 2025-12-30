// Mobile Navigation Toggle
const navToggle = document.querySelector('.nav-toggle');
const navMenu = document.querySelector('.nav-menu');

navToggle.addEventListener('click', () => {
    navMenu.classList.toggle('active');
});

// Close menu when clicking a link
document.querySelectorAll('.nav-menu a').forEach(link => {
    link.addEventListener('click', () => {
        navMenu.classList.remove('active');
    });
});

// Navbar background on scroll
const navbar = document.querySelector('.navbar');

window.addEventListener('scroll', () => {
    if (window.scrollY > 50) {
        navbar.style.background = 'rgba(10, 15, 26, 0.95)';
    } else {
        navbar.style.background = 'rgba(10, 15, 26, 0.8)';
    }
});

// Intersection Observer for scroll animations
const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
};

const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.classList.add('animate-in');
        }
    });
}, observerOptions);

// Observe sections
document.querySelectorAll('.section').forEach(section => {
    observer.observe(section);
});

// Add CSS for animation
const style = document.createElement('style');
style.textContent = `
    .section {
        opacity: 0;
        transform: translateY(30px);
        transition: opacity 0.6s ease, transform 0.6s ease;
    }
    .section.animate-in {
        opacity: 1;
        transform: translateY(0);
    }
`;
document.head.appendChild(style);

// Typing effect for code block (optional enhancement)
const codeBlock = document.querySelector('.card-content code');
if (codeBlock) {
    const originalHTML = codeBlock.innerHTML;
    codeBlock.innerHTML = '';
    
    let i = 0;
    const typeCode = () => {
        if (i < originalHTML.length) {
            // Handle HTML tags
            if (originalHTML[i] === '<') {
                const tagEnd = originalHTML.indexOf('>', i);
                codeBlock.innerHTML += originalHTML.substring(i, tagEnd + 1);
                i = tagEnd + 1;
            } else {
                codeBlock.innerHTML += originalHTML[i];
                i++;
            }
            setTimeout(typeCode, 15);
        }
    };
    
    // Start typing after a delay
    setTimeout(typeCode, 1000);
}

console.log('Portfolio loaded successfully! 🚀');
