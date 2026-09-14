(function(){
  document.getElementById('year').textContent = new Date().getFullYear();

  var header = document.getElementById('siteHeader');
  var onScroll = function(){
    if(window.scrollY > 8){ header.classList.add('scrolled'); }
    else{ header.classList.remove('scrolled'); }
  };
  document.addEventListener('scroll', onScroll, { passive:true });
  onScroll();

  var form = document.getElementById('contactForm');
  var status = document.getElementById('formStatus');
  form.addEventListener('submit', function(e){
    e.preventDefault();
    status.classList.add('show');
    form.querySelectorAll('input, textarea').forEach(function(f){ f.disabled = true; });
    form.querySelector('button[type="submit"]').disabled = true;
    form.querySelector('button[type="submit"]').style.opacity = '0.6';
  });

  var menuBtn = document.querySelector('.menu-btn');
  var links = document.querySelector('nav.links');
  if(menuBtn){
    menuBtn.addEventListener('click', function(){
      var open = links.style.display === 'flex';
      links.style.display = open ? 'none' : 'flex';
      links.style.flexDirection = 'column';
      links.style.position = 'absolute';
      links.style.top = '100%';
      links.style.left = '0';
      links.style.right = '0';
      links.style.background = 'var(--bg)';
      links.style.padding = '18px var(--gutter) 26px';
      links.style.borderBottom = '1px solid var(--line)';
      links.style.gap = '18px';
    });
  }
})();
