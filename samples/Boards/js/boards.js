Pod = Backbone.Model.extend({
    initialize: function() {
        _.bindAll(this, "evaluate", "fixBindings", "podChanged", "getFilePart",
            "getYoutubeMarkup", "getVimeoMarkup", "getPieData",
            "getPieTitle", "trimMapContent", "getMapMarkup");
        this.evaluate();
        this.bind("change", this.podChanged);
    },

    fixBindings: function() {
        var target = null;
        if (this.has("target")) {
            target = this.collection.get(this.get("target"));
        }
        if (target && !this.view.subview.target) {
            target.bind("change:content", this.view.subview.render);
            this.view.subview.target = target;
        }
    },

    evaluate: function() {
        var r_imglink = /^(file|https?):\/\/.+\/.+\.(gif|jpg|jpeg|png)$/i;
        var r_youtube = /^https?:\/\/(?:www\.)?youtube.com\/watch\?(?=.*v=\w+)(?:\S+)?$/i;
        var r_vimeo = /^https?:\/\/(?:www\.)?vimeo.com\/\d+$/i;
        var r_audio = /^(?:file|https?):\/\/.+\/(.+\.(?:mp3|wav|ogg))$/i;
        var r_piedata = /^([^\r\n]+[\r\n]+)?\w+\s+\d[\d.]*\s*[\r\n]+\w+\s+\d[\d.]*\s*[\r\n]+(\w+\s+\d[\d.]*\s*[\r\n]+)*[\r\n]+$/;
        var r_map = /(^!map[\r\n]+|[\r\n]+!map$)/;
        var r_list = /^\s*[-xX][^\r\n]*[\r\n]+(\s*[-xX][^\r\n]*[\r\n]+)+[\r\n]+$/;

        var content = this.get("content");
        if (this.get("mode") == "markdownpreview") {
            return;
        }
        if (r_imglink.test(content)) {
            this.set({"mode" : "image"});
        } else if (r_youtube.test(content)) {
            this.set({"mode" : "youtube"});
        } else if (r_vimeo.test(content)) {
            this.set({"mode" : "vimeo"});
        } else if (r_audio.test(content)) {
            this.set({"mode" : "audio"});
        } else if (r_piedata.test(content)) {
            this.set({"mode" : "piechart"});
        } else if (r_map.test(content)) {
            this.set({"mode" : "map"});
        } else if (r_list.test(content)) {
            this.set({"mode" : "list"});
        } else {
            this.set({"mode" : "text"});
        }
        if (this.get("mode") == "text") {
            var r_markdown = /(^!markdown[\r\n]+)|([\r\n]+!markdown[\r\n]+$)/;
            if (r_markdown.test(content) || this.get("markdowned")) {
                var foundmdpod = null;
                var thisid = this.id;
                podlist.each(function(pod) {
                    if (pod.get("target") == thisid) {
                        foundmdpod = pod;
                    }
                });
                if (!foundmdpod && this.view) {
                    if (r_markdown.test(content)) {
                        content = content.replace(r_markdown, "");
                        this.set({"content": content});
                        $(this.view.el).find("textarea").val(content);
                        $(this.view.el).find("textarea").change();
                    }
                    this.set({"markdowned":true});
                    var position = getElementPosition($(this.view.el));
                    if (position.left > 380)
                        position.left -= 380;
                    else
                        position.left += 380;
                    var data = {
                        "content"   :   content,
                        "mode"      :   "markdownpreview",
                        "offset"    :   position,
                        "z"         :   this.collection.highestZ()+1,
                        "target"    :   this.id,
                    };
                    var pod = new Pod(data);
                    podlist.add(pod);
                }
            }
        }
        this.save();
        console.log("evaluate(): mode:"+this.get("mode"));
    },

    getFilePart: function() {
        var content = this.get("content");
        var filepart = content.substring(content.lastIndexOf("/")+1);
        var r_file = /^([^?#\.]+)/;
        var match = r_file.exec(filepart);
        if (match && match.length > 1) {
            return match[1];
        }
        return null;
    },

    getYoutubeMarkup: function() {
        var youtube_id;
        var r_youtube_id = /(?:\?|&)v=([a-zA-Z0-9_-]+)/;
        var match = r_youtube_id.exec(this.get("content"));
        if (match && match.length > 1) {
            youtube_id = match[1];
        } else {
            return "";
        }
        var old_markup = '<object width="340" height="205"><param name="movie" value="http://www.youtube.com/v/'+youtube_id+'?version=3&amp;hl=en_US"></param><param name="allowFullScreen" value="true"></param><param name="allowscriptaccess" value="always"></param><embed src="http://www.youtube.com/v/'+youtube_id+'?version=3&amp;hl=en_US" type="application/x-shockwave-flash" width="340" height="205" allowscriptaccess="always" allowfullscreen="true"></embed></object>';
        var new_markup = '<iframe class="youtube-player" type="text/html" width="340" height="205" src="http://www.youtube.com/embed/'+youtube_id+'" frameborder="0"></iframe>';
        return old_markup;
    },

    getVimeoMarkup: function() {
        var vimeoid = this.getFilePart(this.get("content"));
        var markup = '<iframe src="http://player.vimeo.com/video/'+vimeoid+'?title=0&amp;byline=0&amp;portrait=0&amp;autoplay=0" width="340" height="205" frameborder="0" webkitAllowFullScreen mozallowfullscreen allowFullScreen></iframe>'
        return markup;
    },

    getPieData: function() {
        var r_piedata = /(\w+)\s+(\d[\d.]*)\s*[\r\n]+/g;
        var content = this.get("content");
        var match = null;
        var data = [];
        var lastindex = null;
        while (match = r_piedata.exec(content)) {
            data.push([match[1], Number(match[2])]);
            if (r_piedata.lastIndex == lastindex) {
                break;
            }
            lastindex = r_piedata.lastIndex;
        }
        return data;
    },

    getPieTitle: function() {
        var content = this.get("content");
        var first = content.substring(0, content.search(/[\r\n]/));
        var r_piedata = /(\w+)\s+(\d[\d.]*)/;
        if (r_piedata.test(first)) {
            return null;
        } else {
            return first;
        }
    },

    trimMapContent: function() {
        var r_map = /(^!map[\r\n]+|[\r\n]+!map$)/;
        var content = this.get("content");
        return content.replace(r_map, "");
    },

    getMapMarkup: function() {
        var address = this.trimMapContent();
        var map = '<iframe width="340" height="300" frameborder="0" scrolling="no" marginheight="0" marginwidth="0" src="http://maps.google.com/maps?f=q&amp;source=s_q&amp;hl=en&amp;geocode=&amp;q='+encodeURIComponent(address)+'&amp;output=embed"></iframe>';
        return map;
    },

    getListItems: function() {
        var r_listitem = /\s*([-xX])([^\r\n]*)[\r\n]+/g;
        var content = this.get("content");
        var match = null;
        var items = [];
        while (match = r_listitem.exec(content)) {
            var checked = false;
            if ($.trim(match[1]) == "-") {
                checked = false;
            } else {
                checked = true;
            }
            if ($.trim(match[1]).length > 0) {
                items.push([checked, $.trim(match[2])]);
            }
        }
        return items;
    },

    podChanged: function() {
        var changed = this.changedAttributes();
        if (changed === false) return;
        if ("content" in changed) {
            this.evaluate();
        }
    },
});

YoutubeView = Backbone.View.extend({
    className: "youtube-view",
    render: function() {
        $(this.el).html(this.model.getYoutubeMarkup());
        return this;
    }
});

VimeoView = Backbone.View.extend({
    className: "vimeo-view",
    render: function() {
        console.log("rendering vimeoview");
        $(this.el).html(this.model.getVimeoMarkup());
        return this;
    }
});

AudioView = Backbone.View.extend({
    className: "audio-view",
    render: function() {
        $(this.el).append('<h4><a href="'+this.model.get("content")+'">'+decodeURIComponent(this.model.getFilePart())+'</a></h4>');
        $(this.el).append('<audio controls="controls"> <source src="'+this.model.get("content")+'" type="audio/mpeg"/>No audio for you :(</audio>');
        return this;
    }
});

PieChartView = Backbone.View.extend({
    className: "pie-view",
    render: function() {
        var topspace = 0;
        if (this.model.getPieTitle()) topspace = 10;
        var chart = new Highcharts.Chart({
            chart: {
                renderTo: $(this.el)[0],
                width: 340,
                height: 340,
                plotBackgroundColor: null,
                plotBorderWidth: null,
                spacingTop: topspace,
                spacingBottom: 0,
                spacingRight: 0,
                spacingLeft: 0
            },
            title: { text: this.model.getPieTitle() },
            tooltip: {
                formatter: function() {
                    return '<b>'+ this.point.name +'</b>: '+ this.y;
                }
            },
            plotOptions: {
             pie: {
                allowPointSelect: true,
                cursor: 'pointer',
                dataLabels: {
                    distance: -40,
                    color: 'white',
                    enabled: true,
                },
                formatter: function() {
                  return '<b>'+ this.point.name +'</b>: '+ this.percentage +' %';
                }
             }
            },
            series: [{
                type: "pie",
                data: this.model.getPieData(),

            }]
        });
        return this;
    }
});

MarkdownView = Backbone.View.extend({
    className: "markdown-view",

    initialize: function(options) {
        _.bindAll(this, "render", "cleanup");

        var id = this.model.get("target");
        var target = this.model.collection.get(id);
        if (target) {
            this.target = target;
            this.target.bind("change:content", this.render);
        } else {
            this.target = null;
        }
        this.converter = new Showdown.converter();
    },

    cleanup: function() {
        if (this.target) {
            this.target.unbind("change:content", this.render);
            this.target.unset("markdowned");
            this.target.save();
        }
        this.converter = null;
    },

    render: function() {
        var content;
        if (this.target) {
            content = this.target.get("content");
            if (content && content != this.model.get("content")) {
                this.model.set({"content": content});
                this.model.save();
            }
        }
        content = this.model.get("content");
        if (content) {
            $(this.el).html(this.converter.makeHtml(content));
        }
        return this;
    }
});

MapView = Backbone.View.extend({
    className: "map-view",
    render: function() {
        $(this.el).html(this.model.getMapMarkup());
        return this;
    }
});

ListView = Backbone.View.extend({
    className: "list-view",
    events: {
        "keyup input:text"      :   "textChanged",
        "click input:checkbox"  :   "itemChecked",
    },
    initialize: function() {
        _.bindAll(this, "render", "textChanged", "itemChecked", "saveToContent");
        this.model.bind("change:content", this.render);
        this.list_template = '<div class="input-prepend"><label class="add-on"><input type="checkbox"></label><input size="14" type="text" style="width:303px" value=""></div>';
    },
    render: function() {
        var items = this.model.getListItems();
        var initelems = elems = $(this.el).find("div.input-prepend");
        var i;
        if (elems.length < items.length) {
            for (i = 0; i < items.length-elems.length; i++) {
                $(this.el).append(this.list_template);
            }
        } else if (elems.length > items.length) {
            var rem_elems = _.last(elems, elems.length-items.length);
            $(rem_elems).remove();
        }
        elems = $(this.el).find("div.input-prepend");
        var text_elem;
        for (i = 0; i < items.length; i++) {
            $(elems[i]).find("input:checkbox").prop('checked', items[i][0]);
            text_elem = $(elems[i]).find("input:text");
            if (text_elem.val() != items[i][1] && !text_elem.is(":focus")) {
                text_elem.val(items[i][1]);
            }
            text_elem.toggleClass('list-done', items[i][0]);
            text_elem.prop('disabled', items[i][0]);
        }
        return this;
    },

    findPrev: function($elem) {
        var found = false;
        while (($elem = $elem.prev())) {
            if ($elem.length == 0)
                return null;
            if ($elem.find("input:checkbox").prop("checked") == false)
                return $elem;
        }
    },
    findNext: function($elem) {
        var found = false;
        while (($elem = $elem.next())) {
            if ($elem.length == 0)
                return null;
            if ($elem.find("input:checkbox").prop("checked") == false)
                return $elem;
        }
    },

    textChanged: function(e) {
        if (!('keyCode' in e)) return;
        if (e.keyCode == 13) { // enter
            $(e.target).parent().after(this.list_template);
            var next = this.findNext($(e.target).parent());
            if (next) { next.find("input:text").focus(); }
            return;
        } else if (e.keyCode == 8) { // backspace
            if ($(e.target).val() == "") {
                var prev = this.findPrev($(e.target).parent());
                if (prev) {
                    prev.find("input:text").focus();
                } else {
                    var next = this.findNext($(e.target).parent());
                    if (next) {
                        next.find("input:text").focus();
                    }
                }
                $(e.target).parent().remove();
            }
        } else if (e.keyCode == 40) { // down arrow
            var next = this.findNext($(e.target).parent());
            if (next) { next.find("input:text").focus(); }
        } else if (e.keyCode == 38) { // up arrow
            var prev = this.findPrev($(e.target).parent());
            if (prev) { prev.find("input:text").focus(); }
        }
        this.saveToContent();
    },

    itemChecked: function(e) {
        this.saveToContent();
    },

    saveToContent: function() {
        var content = "";
        var checkboxes = $(this.el).find("input:checkbox");
        var texts = $(this.el).find("input:text");

        for (var i = 0; i < checkboxes.length; i++) {
            if ($(checkboxes[i]).prop('checked')) {
                content += " X ";
            } else {
                content += " - ";
            }
            content += $(texts[i]).val();
            content += "\n";
        }
        content += "\n";

        if (this.model.get("content") != content) {
            this.model.set({"content":content});
            this.model.save();
        }
    }
});

PodView = Backbone.View.extend({
    className: "pod span6",

    events: {
        "keyup textarea"    :   "textChanged",
        "mousedown"         :   "podDown",
        "click .close"      :   "podClose",
        "blur textarea"     :   "podTextBlurred",
    },

    initialize: function() {
        _.bindAll(this, "render", "textChanged", "dragStopped", "textActive",
            "viewModeChanged", "podClose", "podTextBlurred", "podResized");
        this.model.bind("change:mode", this.viewModeChanged);
        this.model.view = this;
    },

    render: function() {
        var content = this.model.get("content");
        var mode = this.model.get("mode");
        console.log("PodView: render()");
        if ($(this.el).children(".podview").length == 0) {
            $(this.el).append('<a href="#" class="hide close">&times;</a>');
            $(this.el).append('<div class="podview"></div>');
            $(this.el).draggable({containment: ".body", stop: this.dragStopped, cancel: '.podview'});
        }
        var view = $(this.el).find(".podview");
        if (view.children("textarea").length == 0) {
            view.append('<textarea spellcheck="false" class="span6">'+content+'</textarea>');
            view.children("textarea").autoResize({
                minHeight: 36,
                extraSpace: 0,
                onAfterResize: this.podResized,
                animate: false,
            });
        }
        if (mode == "image") {
            view.children("textarea").hide();
            if ($(this.el).children("img").length == 0) {
                $(this.el).append('<img class="thumbnail" src="'+content+'" width="340">');
            } else {
                $(this.el).find("img").show();
            }
        } else if (mode == "youtube") {
            view.children("textarea").hide();
            if (!this.subview) {
                this.subview = new YoutubeView({model: this.model});
                view.append(this.subview.render().el);
            }
        } else if (mode == "vimeo") {
            view.children("textarea").hide();
            if (!this.subview) {
                this.subview = new VimeoView({model: this.model});
                view.append(this.subview.render().el);
            }
        } else if (mode == "audio") {
            view.children("textarea").hide();
            if (!this.subview) {
                this.subview = new AudioView({model: this.model});
                view.append(this.subview.render().el);
            }
        } else if (mode == "piechart") {
            view.children("textarea").hide();
            if (!this.subview) {
                this.subview = new PieChartView({model: this.model});
                view.append(this.subview.render().el);
            }
        } else if (mode == "markdownpreview") {
            view.children("textarea").hide();
            if (!this.subview) {
                this.subview = new MarkdownView({model: this.model});
                view.append(this.subview.render().el);
            } else {
                this.subview.render();
            }
        } else if (mode == "map") {
            view.children("textarea").hide();
            if (!this.subview) {
                this.subview = new MapView({model: this.model});
                view.append(this.subview.render().el);
            }
        } else if (mode == "list") {
            view.children("textarea").hide();
            if (!this.subview) {
                this.subview = new ListView({model: this.model});
                view.append(this.subview.render().el);
            } else {
                this.subview.render();
            }
        } else {
            if (mode != "text") {
                console.log("unknown mode: "+mode+", rendering as text");
            }
            if (this.subview) {
                this.subview.remove();
                this.subview = null;
            }
            $(this.el).find("img").hide();
            if (!this.textActive()) {
                if (view.children("textarea").val() != this.model.get("content")) {
                    view.children("textarea").val(this.model.get("content"));
                    view.children("textarea").change();
                }
            }
            if (!view.children("textarea").is(":visible")) {
                view.children("textarea").show();
            }
        }

        if ($(this.el).css('z-index') != this.model.get("z")) {
            $(this.el).css('z-index', this.model.get("z"));
        }

        console.log("PodView: render() done: [" +content.substring(0, 30)+"..]");
        var pos = this.model.get("offset");
        $(this.el).data('pod-offset', this.model.get("offset"));
        if (this.rendered) {
            app.qUpdateLayout();
        } else {
            this.rendered = true;
        }
        return this;
    },

    viewModeChanged: function() {
        this.render();
    },

    textActive: function() {
        return $(this.el).find("textarea").length && $(this.el).find("textarea").is(":focus");
    },

    textChanged: function(e) {
        if ('keyCode' in e && e.keyCode == 27) {
            if ($.trim(this.model.get("content")).length == 0)
                this.podClose();
            return;
        }
        var uicontent = $(this.el).find("textarea").val();
        var modelcontent = this.model.get("content");
        if (uicontent != modelcontent) {
            this.model.set({"content": uicontent});
        }
    },

    dragStopped: function(e) {
        console.log("drag stopped");
        var pos = getElementPosition($(this.el));
        console.log("pod "+this.model.id+" dragged, x: "+pos.left+" y: "+pos.top+" ");

        $(this.el).data('pod-offset', pos);
        $(this.el).removeClass('no-transition');
        this.model.set({"offset": pos});
        this.model.save();
        return;
    },

    podDown: function(e) {
        if (this.model.get("z") != podlist.highestZ()) {
            this.model.set({"z":podlist.highestZ()+1});
            this.model.save();
            this.render();
        }
        $(this.el).addClass("no-transition");
        return true;
    },

    podClose: function(e) {
        if (e) e.preventDefault();
        console.log("podClose()");
        var mode = this.model.get("mode");
        if (mode == "markdownpreview") {
            this.subview.cleanup();
        }
        if (mode !== "text" && mode !== "markdownpreview") {
            var change = {"mode":"text"};
            var content = this.model.get("content");
            if (mode == "piechart" || mode == "list") {
                change["content"] = content.replace(/\s*$/, "");
            } else if (mode == "map") {
                change["content"] = content.replace(/(^!map[\r\n]+|[\r\n]+!map$)/, "");
            }
            if ("content" in change) {
                $(this.el).find("textarea").val(change["content"]);
                $(this.el).find("textarea").change();
            }
            this.model.set(change, {silent:true});
            this.model.save();
            this.render();
            $(this.el).find("textarea").focus();
        } else {
            this.model.destroy();
        }
        return false;
    },

    podTextBlurred: function(e) {
        if ($.trim(this.model.get("content")).length == 0) {
            this.podClose();
        }
    },

    podResized: function() {
    },
});


PodList = Backbone.SimperiumCollection.extend({
    model: Pod,

    highestZ: function() {
        var z = 0;
        this.each(function(pod) {
            if (pod.get("z") > z) {
                z = pod.get("z");
            }
        });
        return z;
    },

    local_data: function(id) {
        var pod = this.get(id);
        if (pod) {
            if (pod.view && pod.view.textActive()) {
                var poddata = pod.toJSON();
                var $text = $(pod.view.el).find("textarea");
                poddata["content"] = $text.val();
                return [poddata, "content", $text[0]];
            } else {
                return pod.toJSON();
            }
        }
        return null;
    }
});

AppView = Backbone.View.extend({
    el: ".body",
    events: {
        "click"  :   "createPod",
    },

    initialize: function() {
        _.bindAll(this, "updatePod", "createPod", "addPod", "removePod",
            "render", "cleanup", "saveScreenPositions", "enableTransitions",
            "queue_work", "run_queue", "queue_done",
            "qUpdateLayout", "qShuffleLayout", "ready");
        console.log("initialized");
        this.collection.on('add', this.addPod);
        this.collection.on('remove', this.removePod);
        this.collection.on('change', this.updatePod);
        this.collection.on('ready', this.ready);
        this.workq = [];
    },

    updatePod: function(pod) {
        console.log("pod update");
        if (pod.view) {
            pod.view.render();
        }
    },

    createPod: function(e) {
        if (e.target.className.search(/body/) == -1) {
            return true;
        }
        e.preventDefault();
        var defaults = {
            "content"   :   "",
            "mode"      :   "text",
            "offset"    :   {top:e.pageY-60, left:e.pageX},
            "z"         :   this.collection.highestZ()+1,
        };
        var pod = new Pod(defaults);
        this.collection.add(pod);
        if (pod.view) {
            $(pod.view.el).find("textarea").focus();
        }
        return false;
    },

    addPod: function(pod) {
        var podview = new PodView({model: pod});
        $(this.el).append(podview.el)
        podview.render();
        console.log("addPod()");
        pod.save();
        this.queue_work(this, 'enableTransitions', null);
        this.queue_work($(this.el), 'isotope', ['option', {layoutMode: 'boards'}]);
        this.queue_work($(this.el), 'isotope', ['insert', $(podview.el)]);
    },

    removePod: function(pod) {
        console.log("removePod()");
        this.queue_work(this, 'enableTransitions', null);
        this.queue_work($(this.el), 'isotope', ['option', {layoutMode: 'boards'}]);
        this.queue_work($(this.el), 'isotope', ['remove', $(pod.view.el)]);
    },

    saveScreenPositions: function() {
        console.log("saveScreenPositions()");
        this.collection.each(function(pod) {
            if (!pod.view) return;
            var pos = getElementPosition($(pod.view.el));
            $(pod.view.el).data('pod-offset', pos);
            pod.set({"offset": pos});
            pod.save();
        });
    },

    enableTransitions: function() {
        console.log("enableTransitions()");
        this.collection.each(function(pod) {
            if (!pod.view) return;
            if (!$(pod.view.el).hasClass('ui-draggable-dragging')) {
                $(pod.view.el).removeClass('no-transition');
            }
        });
    },

    queue_work: function(obj, fnName, args, timeout) {
        if (timeout) {
            this.workq.push([obj, fnName, args, timeout]);
        } else {
            this.workq.push([obj, fnName, args]);
        }
        this.run_queue();
    },

    run_queue: function() {
        if (this.workq.length == 0) return;
        if (this._queue_timer) return;

        // run item
        var work = this.workq[0];
        work[0][work[1]].apply(work[0], work[2]);
        this.workq = _.rest(this.workq);
        if (work.length == 4) {
            this._queue_timer = setTimeout(this.queue_done, work[3])
        } else {
            this.run_queue();
        }
    },

    queue_done: function() {
        console.log("finish queue timer work");
        this._queue_timer = null;
        this.run_queue();
    },

    qUpdateLayout: function() {
        var layout_queued = _.any(this.workq, function(work) {
            if (work[1] == 'isotope' && work[2] != null &&
                work[2].length > 0 && work[2][0] == 'reLayout')
                return true;
            return false;
        });
        if (layout_queued) return;
        this.queue_work(this, 'enableTransitions', null);
        this.queue_work($(this.el), 'isotope', ['option', {layoutMode: 'boards'}]);
        this.queue_work($(this.el), 'isotope', ['reLayout'], 400);
    },

    qShuffleLayout: function() {
        var layout_queued = _.any(this.workq, function(work) {
            if (work[1] == 'isotope' && work[2] != null &&
                work[2].length > 0 && work[2][0] == 'shuffle')
                return true;
            return false;
        });
        if (layout_queued) return;
        this.queue_work(this, 'enableTransitions', null);
        this.queue_work($(this.el), 'isotope', ['option', {layoutMode: 'masonry'}]);
        this.queue_work($(this.el), 'isotope', ['shuffle'], 400);
        this.queue_work(this, 'saveScreenPositions', null);
    },

    render: function() {
        $(".isogo").show();
        $(this.el).isotope({
            transformsEnabled: true,
            resizable: false,
            resizesContainer: false,
            layoutMode: 'boards',
            itemSelector: '.pod',
            masonry: {
                columnWidth: 380
            },
        });
        $(this.el).show();
    },

    ready: function() {
        console.log("podlist: ready()");
        this.collection.each(function(pod) {
            pod.fixBindings();
        });
    },

    cleanup: function() {
        if ($(this.el).hasClass('isotope')) {
            $(this.el).isotope('destroy');
        }
        $(this.el).children().remove();
        $(this.el).hide();
    }
});

LoaderView = Backbone.View.extend({
    el: ".loader",
    events: {
        "keyup"     :   "keyPressed",
    },

    initialize: function() {
        console.log("loader view initialized");
        _.bindAll(this, "checkVal", "keyPressed", "cleanup", "render");
    },

    checkVal: function() {
        var name = $.trim($(this.el).find("input").val());
        var r_board = /^[a-zA-Z0-9]+$/;
        $(this.el).find("input").val('');
        if (r_board.exec(name)) {
            return name.toLowerCase();
        }
        return "";
    },

    keyPressed: function(e) {
        if (e.keyCode == 13) {
            var boardname = this.checkVal();
            if (boardname.length > 0) {
                console.log("submit: "+boardname);
                router.navigate(boardname, true);
            }
        }
    },

    cleanup: function() {
        $(this.el).hide();
        $(this.el).find("input").val("");
    },

    render: function() {
        $(".isogo").hide();
        $(this.el).show();
        $(this.el).find("input").focus();
        return this;
    },

});

NavView = Backbone.View.extend({
    el: ".topbar",

    events: {
        "click .isogo"    :   "doShuffle",
    },

    initialize: function() {
        _.bindAll(this, "render", "doShuffle");
    },

    render: function(barray) {
        var view = $(this.el).find(".nav");
        view.children().remove();
        _.each(barray, function(board) {
            view.append('<li><a href="#'+board+'">'+board+'</a></li>');
        });
    },

    doShuffle: function() {
        if (!app) return;
        app.qShuffleLayout();
        return;
    }
});

var getElementPosition = function($elem) {
    if (Modernizr.csstransforms) {
        var t = $elem.css('translate');
        ret = { 'top':t[1], 'left':t[0] };
    } else {
        ret = $elem.position();
    }
    ret.top = Math.round(ret.top);
    ret.left = Math.round(ret.left);
    return ret;
};

var getBoardArray = function() {
    var boardhistory = $.cookie('boardhistory');
    if (!boardhistory) return [];
    var barray = [];
    var s = boardhistory.split(",");
    var r_board = /^[a-zA-Z0-9]+$/;
    for (var i = 0; i < s.length; i++) {
        if (r_board.test(s[i])) barray.push($.trim(s[i].toLowerCase()));
    }
    return barray;
};

var saveBoardArray = function(barray) {
    var bstr = "";
    _.each(barray, function(board) {
        board = board.toLowerCase();
        if (bstr.length > 0) bstr += ",";
        bstr += board;
    });
    $.cookie('boardhistory', bstr, {expires: 1, path:'/'});
};

var updateCookieHistory = function(board) {
    var barray = getBoardArray();
    board = board.toLowerCase();
    barray = _.without(barray, board);
    barray = _.union([board], barray);
    barray = _.first(barray, 7);
    saveBoardArray(barray);
};

simperium_options = {
    token           : 'SIMPERIUM_ACCESS_TOKEN',
    update_delay    : 3,
};
app_id = 'SIMPERIUM_APP_ID';

var BoardRouter = Backbone.Router.extend({
    routes: {
        "*path"             :   "defaultPage",
    },

    initialize: function() {
        _.bindAll(this, "loadBoard", "defaultPage");
        this.route(/^([a-zA-Z0-9]+)$/, "board", this.loadBoard);
    },

    loadBoard: function(board) {
        var r_board = /^[a-zA-Z0-9]+$/;
        if (r_board.test(board) == false) {
            this.navigate("", true);
            return;
        }
        if (loader) loader.cleanup();
        if (app) app.cleanup();
        podlist = null;
        simperium = null;
        app = null;

        updateCookieHistory(board);
//        navview.render(getBoardArray());
        simperium = new Simperium(app_id, simperium_options);
        podlist = new PodList([], {bucket:simperium.bucket(board)});
        app = new AppView({collection: podlist});
        app.render();
    },

    defaultPage: function(path) {
        if (app) app.cleanup();
//        navview.render(getBoardArray());
        var random = (((1+Math.random())*0x10000)|0).toString(16);
        this.navigate(random);
        this.loadBoard(random);
//        if (!loader) loader = new LoaderView();
//        loader.render();
    },

});

$.extend( $.Isotope.prototype, {
    _boardsReset: function() {
        console.log("_boardsReset()");
        this.boards = {
            height: 0
        };
    },
    _boardsLayout: function($elems) {
        console.log("_boardsLayout()");
        var instance = this;
        $elems.each(function() {
            var $this = $(this);
            var data_position = $this.data('pod-offset');
            var atomH = $this.outerHeight(true);
            var x = Math.round(data_position.left);
            var y = Math.round(data_position.top);
            if (y + atomH > instance.boards.height) {
                instance.boards.height = y + atomH;
            }
            if (typeof x != 'number' || isNaN(x)) x = 0;
            if (typeof y != 'number' || isNaN(y)) y = 0;
            var pos = getElementPosition($this);
            if (((Math.abs(x-pos.left) > 1 || Math.abs(y-pos.top) > 1)) &&
                !$this.hasClass('ui-draggable-dragging')) {
                instance._pushPosition($this, x, y);
            }
        });
        console.log("_boardsLayout() total height: "+instance.boards.height);
    },
    _boardsGetContainerSize: function() {
        console.log("_boardsGetContainerSize() returns "+this.boards.height);
        return { height: this.boards.height };
    },
    _boardsResizeChanged: function() {
        console.log("_boardsResizeChanged()");
        return true;
    }
});

$(document).ready(function() {
    console.log("started");
    app = null;
    loader = null;
    navview = new NavView();
    router = new BoardRouter();
    Backbone.history.start();
});
