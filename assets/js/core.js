function listenToRouterLocationChanged(callback) {
  addEventListener('routerLocationChanged', async function (e) {
    callback(e.detail.pathname);

    findAnyReactComponent();
  }, false);

  callback(location.pathname);
}

addEventListener('routerLocationChanged', async function (e) {
  // Call Flutter JavaScript handler callback
  await window.flutter_inappwebview.callHandler('routerLocationChanged', e.detail);
}, false);