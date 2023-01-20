function _handleListeningOnCurrentPage(urlPath) {
    let onFormsScreen = false;

    // console.log('_handleListeningOnCurrentPage: ' + urlPath);
    if ((urlPath === '/projects') || urlPath.startsWith('/projects/')
        || (urlPath === '/departments') || urlPath.startsWith('/departments/')) {
        hideAllDocumentsTab();

        if (urlPath.endsWith('/forms')) {
            onFormsScreen = true;
            hideFormsControls();
        }

        setAddButtonVisibility(onFormsScreen);
    }
}

listenToRouterLocationChanged(_handleListeningOnCurrentPage);

function hideAllDocumentsTab() {
    const allDocumentsTab = document
        .evaluate('//div[contains(@class, \'MuiTabs-root\')]'
            + '//div[contains(@class, \'MuiTabs-flexContainer\')]'
            + '//button[.//*[contains(text(), \'Documents\')]]', document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null)
        .singleNodeValue;
    if (allDocumentsTab) {
        allDocumentsTab.style.display = 'none';
    }
}

function hideFormsControls() {
    // Hide the "Designer" button on each of the Forms cards
    const formCardDesignerBtns = document
        .evaluate('//*[contains(@class, \'MuiCardActions-root\')]'
            /*+ '/div[./button[@aria-label=\'Designer\']]'*/, document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);

    if (formCardDesignerBtns) {
        for (let i = 0, length = formCardDesignerBtns.snapshotLength; i < length; ++i) {
            const formCardDesignerBtn = formCardDesignerBtns.snapshotItem(i);
            formCardDesignerBtn.style.display = 'none';
        }
    }
}

function setAddButtonVisibility(onFormsScreen) {
    const addButton = document
        .evaluate('//button[@aria-label=\'Add\']', document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null)
        .singleNodeValue;
    if (addButton) {
        addButton.style.display = onFormsScreen ? 'none' : '';
    }
}