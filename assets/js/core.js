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

  const signInGoogleReactBtn = document
    .evaluate('//div[contains(@class, \'MuiGrid-item\') and //button//span[contains(@class, \'MuiButton-label\') and contains(.//text(), \'Google\')]]', document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null)
    .singleNodeValue;
  const signInGoogleReactBtnRect = signInGoogleReactBtn.getBoundingClientRect();
  
  let googleLoginOverlayBtn = document.createElement("div");
  const btnStyle = googleLoginOverlayBtn.style;
  btnStyle.backgroundColor = '#00000000';
  btnStyle.position = 'absolute';
  btnStyle.height = signInGoogleReactBtnRect.height + 'px';
  btnStyle.left = '45px';
  btnStyle.right = '45px';
  btnStyle.zIndex = 999;
  googleLoginOverlayBtn = signInGoogleReactBtn.parentElement.appendChild(googleLoginOverlayBtn);
  
  _listenForLoginEventsListener = googleLoginOverlayBtn.addEventListener('click', (e) => {
    // Call Flutter JavaScript handler callback
    window.flutter_inappwebview.callHandler('login_handleGoogleLogin', e.detail);
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