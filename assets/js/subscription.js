function _handleListeningOnCurrentPage(urlPath) {
  if (urlPath === '/home') {
    hideSubscriptionButtonOnHome();
  } else if (urlPath.startsWith('/organizationManagement/') && urlPath.endsWith('/members')) {
    hideSubscriptionTabOnOrgManagement();
  }
}

listenToRouterLocationChanged(_handleListeningOnCurrentPage);

function hideSubscriptionButtonOnHome() {
  const subscriptionReactBtn = document
    .evaluate('//div[contains(@class, \'MuiGrid-item\') and contains(.//button//p//text(), \'Subscription\')]', document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null)
    .singleNodeValue;
  
  if (!subscriptionReactBtn) {
    return;
  }
  subscriptionReactBtn.style.display = 'none';
}

function hideSubscriptionTabOnOrgManagement() {
  const subscriptionTab = document
    .evaluate('//div[contains(@class, \'MuiTabs-root\')]'
      + '//div[contains(@class, \'MuiTabs-flexContainer\')]'
      + '//button[2]', document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null)
    .singleNodeValue;
  if (!subscriptionTab) {
    return;
  }
  
  subscriptionTab.style.display = 'none';
}