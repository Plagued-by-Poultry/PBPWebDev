let turnstileWidgetId = null;

window.onloadTurnstileCallback = function () {
    const container = document.getElementById('turnstile-container');
    if (!container) return;

    // Dev testing uses a different key....
    const isLocal = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';
    const devSiteKey = "1x00000000000000000000AA"; // See https://developers.cloudflare.com/turnstile/troubleshooting/testing/
    const prodSiteKey = "0x4AAAAAAE23nKP9dVrYu3VU";

    const activeKey = isLocal ? devSiteKey : prodSiteKey;

    turnstileWidgetId = turnstile.render('#turnstile-container', {
        sitekey: activeKey,
        theme: 'dark'
    });
};

if (window.turnstile) {
    window.onloadTurnstileCallback();
} else {
    window.turnstile = {
        ready: function (cb) {
            window.onloadTurnstileCallback();
        }
    };
}


document.getElementById('contactForm').addEventListener('submit', async (e) => {
    e.preventDefault();

    const statusText = document.getElementById('formStatus');
    statusText.innerText = "Processing message...";
    statusText.style.display = "block";

    const formData = new FormData();
    formData.append('name', document.getElementById('f-name').value);
    formData.append('email', document.getElementById('f-email').value);
    formData.append('message', document.getElementById('f-message').value);

    const turnstileWidget = document.querySelector('[name="cf-turnstile-response"]');
    if (!turnstileWidget || !turnstileWidget.value) {
        statusText.innerText = "Please complete the security verification box before sending.";
        return;
    }
    formData.append('cf-turnstile-response', turnstileWidget.value);

    // Post data to ASP processor....

    try {
        const response = await fetch('/processors/contact-us.aspx', {
            method: 'POST',
            body: formData
        });

        const result = await response.json();

        if (result.success) {

            statusText.innerText = "Thanks, that landed in our inbox. We'll write back soon.";
            document.getElementById('contactForm').reset();

            if (typeof turnstile !== 'undefined') {
                turnstile.reset();
            }
        } else {
            statusText.innerText = "Submission failed: " + result.message;
        }
    } catch (error) {
        statusText.innerText = "Something went wrong on our end, please try again later!";
    }

});