function listenToRouterLocationChanged() {
  addEventListener('routerLocationChanged', async function (e) {
    // Call Flutter JavaScript handler callback
    await window.flutter_inappwebview.callHandler('routerLocationChanged', e.detail);
  }, false);
}

listenToRouterLocationChanged();