// ══════════════════════════════════════════════════════════════════════════════
// GHL → SHOPIFY CUSTOMER BUTTON
// Host this file on GitHub Gist, then use the loader script in GHL
// ══════════════════════════════════════════════════════════════════════════════

(function() {
  // ══════════════════════════════════════════════════════════════════════════════
  // CONFIGURATION - Edit these values as needed
  // ══════════════════════════════════════════════════════════════════════════════
  const CONFIG = {
    // Only run on this specific sub-account
    locationId: 'e3OK9OEwoleo4Knk0xos',
    
    // Your white-label domain (without https://)
    domain: 'app.myaileads.co',
    
    // Shopify store name
    shopifyStore: 'ultracurretail',
    
    // The EXACT label of your custom field as it appears in the contact view
    // Change this to match your field's display name
    customFieldLabel: 'Shopify Customer ID',
    
    // Button text
    buttonText: 'View in Shopify',
    
    // Button ID (for preventing duplicates)
    buttonId: 'ghl-shopify-link-btn'
  };

  // ══════════════════════════════════════════════════════════════════════════════
  // LOCATION CHECK - Exit if not on the target sub-account
  // ══════════════════════════════════════════════════════════════════════════════
  function isCorrectLocation() {
    return window.location.href.includes('/location/' + CONFIG.locationId);
  }

  function isContactDetailPage() {
    return window.location.href.includes('/contacts/detail/');
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // SHOPIFY ID EXTRACTION - Find the custom field value in the DOM
  // ══════════════════════════════════════════════════════════════════════════════
  function getShopifyCustomerId() {
    // Method 1: Look for custom field by label text
    const labels = document.querySelectorAll('label, span, div, p');
    for (const label of labels) {
      if (label.textContent.trim().toLowerCase() === CONFIG.customFieldLabel.toLowerCase()) {
        // Check siblings and parent containers for the value
        const parent = label.closest('div[class*="field"], div[class*="custom"], div[class*="row"], div');
        if (parent) {
          const valueElements = parent.querySelectorAll('span, div, input, p');
          for (const el of valueElements) {
            const text = el.textContent.trim();
            // Shopify customer IDs are numeric
            if (text && /^\d+$/.test(text) && text.length > 5) {
              return text;
            }
            // Check input values
            if (el.tagName === 'INPUT' && el.value && /^\d+$/.test(el.value.trim())) {
              return el.value.trim();
            }
          }
        }
      }
    }

    // Method 2: Look for data attributes or specific class patterns
    const customFieldContainers = document.querySelectorAll('[class*="custom-field"], [class*="customField"], [data-field-key*="shopify"]');
    for (const container of customFieldContainers) {
      if (container.textContent.toLowerCase().includes('shopify')) {
        const matches = container.textContent.match(/\d{10,}/);
        if (matches) return matches[0];
      }
    }

    // Method 3: Search all text content for a pattern near "shopify"
    const allText = document.body.innerHTML;
    const shopifyPattern = new RegExp(CONFIG.customFieldLabel.replace(/\s+/g, '[\\s\\S]*?') + '[\\s\\S]*?(\\d{10,})', 'i');
    const match = allText.match(shopifyPattern);
    if (match && match[1]) return match[1];

    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // BUTTON INJECTION - Create and insert the Shopify button
  // ══════════════════════════════════════════════════════════════════════════════
  function createShopifyButton() {
    // Don't create if already exists
    if (document.getElementById(CONFIG.buttonId)) return;

    const shopifyId = getShopifyCustomerId();
    
    const button = document.createElement('button');
    button.id = CONFIG.buttonId;
    button.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="margin-right: 6px;">
        <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path>
        <polyline points="9 22 9 12 15 12 15 22"></polyline>
      </svg>
      ${CONFIG.buttonText}
    `;
    
    // Apply styles
    Object.assign(button.style, {
      position: 'fixed',
      top: '70px',
      right: '20px',
      zIndex: '9999',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '10px 18px',
      fontSize: '13px',
      fontWeight: '600',
      color: '#ffffff',
      background: 'linear-gradient(135deg, #96bf48 0%, #5e8e3e 100%)',
      border: 'none',
      borderRadius: '8px',
      cursor: shopifyId ? 'pointer' : 'not-allowed',
      boxShadow: '0 4px 14px rgba(150, 191, 72, 0.4)',
      transition: 'all 0.2s ease',
      fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
      opacity: shopifyId ? '1' : '0.6'
    });

    // Hover effects
    button.addEventListener('mouseenter', function() {
      if (shopifyId) {
        this.style.transform = 'translateY(-2px)';
        this.style.boxShadow = '0 6px 20px rgba(150, 191, 72, 0.5)';
      }
    });
    
    button.addEventListener('mouseleave', function() {
      this.style.transform = 'translateY(0)';
      this.style.boxShadow = '0 4px 14px rgba(150, 191, 72, 0.4)';
    });

    // Click handler
    button.addEventListener('click', function() {
      const currentShopifyId = getShopifyCustomerId();
      if (currentShopifyId) {
        const shopifyUrl = `https://admin.shopify.com/store/${CONFIG.shopifyStore}/customers/${currentShopifyId}`;
        window.open(shopifyUrl, '_blank');
      } else {
        alert('Shopify Customer ID not found for this contact.\n\nMake sure the "' + CONFIG.customFieldLabel + '" field has a value.');
      }
    });

    // Tooltip
    button.title = shopifyId 
      ? `Open Shopify Customer #${shopifyId}` 
      : 'Shopify Customer ID not found';

    document.body.appendChild(button);
  }

  function removeShopifyButton() {
    const existing = document.getElementById(CONFIG.buttonId);
    if (existing) existing.remove();
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // PAGE MONITORING - Watch for navigation changes (SPA behavior)
  // ══════════════════════════════════════════════════════════════════════════════
  function checkAndInject() {
    if (!isCorrectLocation()) {
      removeShopifyButton();
      return;
    }

    if (isContactDetailPage()) {
      // Delay slightly to allow DOM to fully render
      setTimeout(createShopifyButton, 500);
    } else {
      removeShopifyButton();
    }
  }

  // Initial check
  checkAndInject();

  // Watch for URL changes (SPA navigation)
  let lastUrl = location.href;
  const urlObserver = new MutationObserver(() => {
    if (location.href !== lastUrl) {
      lastUrl = location.href;
      removeShopifyButton();
      setTimeout(checkAndInject, 300);
    }
  });
  
  urlObserver.observe(document.body, { childList: true, subtree: true });

  // Also listen for popstate (back/forward navigation)
  window.addEventListener('popstate', () => {
    removeShopifyButton();
    setTimeout(checkAndInject, 300);
  });

  // Re-check periodically to catch dynamic content loading
  setInterval(() => {
    if (isCorrectLocation() && isContactDetailPage() && !document.getElementById(CONFIG.buttonId)) {
      createShopifyButton();
    }
  }, 2000);

})();
