/*
 * plugin_hello.js
 * Solar2D Hello Plugin - HTML5/Web JavaScript Implementation
 *
 * Copyright (c) 2026 Eetu Rantanen
 * MIT License
 */

window.plugin_hello = {
    getGreeting: function() {
        var now = new Date();
        var hours = String(now.getHours()).padStart(2, '0');
        var minutes = String(now.getMinutes()).padStart(2, '0');
        var seconds = String(now.getSeconds()).padStart(2, '0');
        var timeStr = hours + ':' + minutes + ':' + seconds;
        return "Hello from HTML5! The time is currently " + timeStr + ".";
    }
};
