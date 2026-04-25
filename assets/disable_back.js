(function(){
  // disable_back.js
  // Usage: <script src="assets/disable_back.js" data-redirect="/somepage.php"></script>
  // If user presses back, they'll be redirected to the URL provided in data-redirect.

  try {
    var currentScript = document.currentScript;
    var redirect = '/';
    if (currentScript) {
      var d = currentScript.getAttribute('data-redirect');
      if (d) redirect = d;
    }

    // Replace current state and add a new history entry to make back go to popstate
    history.replaceState(null, document.title, location.href);
    history.pushState(null, document.title, location.href);

    window.addEventListener('popstate', function (e) {
      // Check if this is a hash change (anchor navigation) - allow it
      if (location.hash) {
        // This is an anchor navigation, don't interfere
        return;
      }
      
      // Prevent navigation back: redirect to provided target
      try {
        // small delay to ensure browser has processed popstate
        setTimeout(function(){ location.replace(redirect); }, 10);
      } catch (ex) {
        // fallback: reload current page
        location.replace(redirect);
      }
    });
  } catch (e) {
    // no-op on older browsers
    console.error('disable_back.js error', e);
  }
})();
