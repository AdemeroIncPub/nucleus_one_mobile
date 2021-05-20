function listenToRouterLocationChanged() {
  addEventListener('routerLocationChanged', async function (e) {
    // Call Flutter JavaScript handler callback
    await window.flutter_inappwebview.callHandler('routerLocationChanged', e.detail);
    _handleListeningOnCurrentPage(e.detail.pathname);
  }, false);
  
  _handleListeningOnCurrentPage(location.pathname);
}

function _handleListeningOnCurrentPage(urlPath) {
  console.log('_handleListeningOnCurrentPage: ' + urlPath);
  if (urlPath === '/login') {
    listenForLoginEvents();
  } else {
    stopListeningForLoginEvents();
  }
}

function initialize() {
  loadScriptsAsync();
}

initialize();

function loadScriptsAsync() {
  const scriptsToLoad = [
    'https://unpkg.com/react@16.13.1/umd/react.development.js',
    'https://unpkg.com/react-dom@16.13.1/umd/react-dom.development.js'
  ];
  var loadedCount = 0;
  for (const s of scriptsToLoad) {
    const script = document.createElement('script');
    script.onload = function () {
      if (++loadedCount === scriptsToLoad.length) {
        allScriptsLoaded();
      }
    };
    script.src = s;

    document.head.appendChild(script);
  }
}

function allScriptsLoaded() {
  listenToRouterLocationChanged();
}


var _listenForLoginEventsListener;

function listenForLoginEvents() {
  // root is the root of your React application
  const root = document.querySelector('#root');

  _listenForLoginEventsListener = root.addEventListener('click', (e) => {
    if ((e.target.tagName === 'SPAN') && (e.target.classList.contains('MuiButton-label'))) {
      if (e.target.innerHTML.includes('Google')) {
        e.stopPropagation();
        // location.href = 'http://stackoverflow.com';

        // Call Flutter JavaScript handler callback
        window.flutter_inappwebview.callHandler('login_handleGoogleLogin', e.detail);
      }
    }
  });
}

function stopListeningForLoginEvents() {
  if (_listenForLoginEventsListener) {
    console.log('Stopping listening...');

    // root is the root of your React application
    const root = document.querySelector('#root');
    root.removeEventListener(_listenForLoginEventsListener);
    _listenForLoginEventsListener = undefined;
  }
}