function _handleListeningOnCurrentPage(urlPath) {
  console.log('_handleListeningOnCurrentPage: ' + urlPath);
  if (urlPath === '/login') {
    listenForLoginEvents();
  } else {
    stopListeningForLoginEvents();
  }
}

listenToRouterLocationChanged(_handleListeningOnCurrentPage);

var _listenForLoginEventsListener;

function listenForLoginEvents() {
  // root is the root of your React application
  const root = document.querySelector('#root');

  const signInGoogleReactBtn = document
    .evaluate('//div[contains(@class, \'MuiGrid-item\') and .//iframe[contains(@src, \'.google.com\')]]', document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null)
    .singleNodeValue;

  if (!signInGoogleReactBtn) {
    console.log('Unable to find Google Sign-In button');
    return;
  }

  const signInGoogleReactBtnRect = signInGoogleReactBtn.getBoundingClientRect();

  let googleLoginOverlayBtn = document.createElement("div");
  const btnStyle = googleLoginOverlayBtn.style;
  btnStyle.backgroundColor = '#00000000';
  btnStyle.position = 'absolute';
  btnStyle.top = signInGoogleReactBtnRect.top + 'px';
  btnStyle.height = signInGoogleReactBtnRect.height + 'px';
  btnStyle.left = signInGoogleReactBtnRect.left + 'px';
  btnStyle.width = signInGoogleReactBtnRect.width + 'px';
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