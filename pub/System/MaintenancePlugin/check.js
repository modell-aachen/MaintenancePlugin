jQuery(function($) {
    if(/\bmpcheck=(?:safe|1)\b/.test(window.location.search)) {
        // we do not want to use window.location.hash, because the user should
        // be able to just 'hit enter' on the location bar to redo the check.
        var position = $('#MP_CHECK').position();
        if(position && position.top) {
            window.scrollTo(0, position.top);
        }
    }
});
