/* =====================================================
   noteflow Landing Page - Interactivity
   ===================================================== */

(function () {
  'use strict';

  // ============ NAVBAR SCROLL EFFECT ============
  const navbar = document.getElementById('navbar');
  const backToTop = document.getElementById('backToTop');

  function onScroll() {
    const y = window.scrollY;
    if (y > 50) {
      navbar.classList.add('scrolled');
    } else {
      navbar.classList.remove('scrolled');
    }
    if (y > 400) {
      backToTop.classList.add('show');
    } else {
      backToTop.classList.remove('show');
    }
  }

  window.addEventListener('scroll', onScroll, { passive: true });

  // ============ MOBILE MENU ============
  const menuToggle = document.getElementById('menuToggle');
  const navLinks = document.getElementById('navLinks');

  if (menuToggle && navLinks) {
    menuToggle.addEventListener('click', () => {
      navLinks.classList.toggle('active');
      const icon = menuToggle.querySelector('i');
      if (icon) {
        icon.classList.toggle('fa-bars');
        icon.classList.toggle('fa-times');
      }
    });

    // Close menu when link clicked
    navLinks.querySelectorAll('a').forEach(link => {
      link.addEventListener('click', () => {
        navLinks.classList.remove('active');
        const icon = menuToggle.querySelector('i');
        if (icon) {
          icon.classList.add('fa-bars');
          icon.classList.remove('fa-times');
        }
      });
    });
  }

  // ============ BACK TO TOP ============
  if (backToTop) {
    backToTop.addEventListener('click', () => {
      window.scrollTo({ top: 0, behavior: 'smooth' });
    });
  }

  // ============ SMOOTH SCROLL FOR ANCHOR LINKS ============
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
      const target = document.querySelector(this.getAttribute('href'));
      if (target) {
        e.preventDefault();
        const navHeight = navbar ? navbar.offsetHeight : 0;
        const top = target.getBoundingClientRect().top + window.scrollY - navHeight;
        window.scrollTo({ top, behavior: 'smooth' });
      }
    });
  });

  // ============ DOWNLOAD BUTTON TRACKING ============
  const downloadBtn = document.getElementById('downloadBtn');
  if (downloadBtn) {
    downloadBtn.addEventListener('click', function (e) {
      console.log('noteflow APK download initiated');
    });
  }

  // ============ USSD DIAL BUTTON ============
  // Opens the device dialer with the subscription code pre-filled.
  // `tel:` is the universal URI scheme — on Android it lands on the dial pad.
  const ussdDialBtn = document.getElementById('ussdDialBtn');
  if (ussdDialBtn) {
    ussdDialBtn.addEventListener('click', function () {
      console.log('USSD dial initiated: 45334');
    });
  }

  // ============ INTERSECTION OBSERVER - FADE IN ON SCROLL ============
  if ('IntersectionObserver' in window) {
    const observerOptions = {
      threshold: 0.1,
      rootMargin: '0px 0px -50px 0px'
    };

    const fadeInObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.style.opacity = '1';
          entry.target.style.transform = 'translateY(0)';
        }
      });
    }, observerOptions);

    // Prepare elements
    const animatables = document.querySelectorAll('.feature-card, .step, .subscribe-card, .download-card');
    animatables.forEach(el => {
      el.style.opacity = '0';
      el.style.transform = 'translateY(30px)';
      el.style.transition = 'opacity 0.6s ease-out, transform 0.6s ease-out';
      fadeInObserver.observe(el);
    });
  }

  // ============ CONSOLE WELCOME ============
  console.log(
    '%c📝 noteflow',
    'background: linear-gradient(135deg, #667eea, #764ba2); color: white; padding: 10px 20px; border-radius: 8px; font-size: 14px; font-weight: bold;'
  );
  console.log('App: NADB26105/noteflow | Built with Flutter | Android | Version 1.0.0');
})();

