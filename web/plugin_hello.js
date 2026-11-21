/*
 * plugin_hello.js
 * Solar2D Hello Plugin - HTML5/Web JavaScript Implementation
 */

window.plugin_hello = {
    getGreeting: function() {
        const now = new Date();
        const hours = String(now.getHours()).padStart(2, '0');
        const minutes = String(now.getMinutes()).padStart(2, '0');
        const seconds = String(now.getSeconds()).padStart(2, '0');
        const timeStr = hours + ':' + minutes + ':' + seconds;
        return "Hello from HTML5! The time is currently " + timeStr + ".";
    }
};
