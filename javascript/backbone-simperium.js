Backbone.SimperiumCollection = Backbone.Collection.extend({
    initialize: function(models, options) {
        _.bindAll(this, "remote_update", "local_data");
        this.bucket = options.bucket;
        this.bucket.on('notify',this.remote_update);
        this.bucket.on('local',this.local_data);
        this.bucket.start();
    },

    remote_update: function(id, data, version) {
        var model = this.get(id);
        if (data == null) {
            if (model) {
                model.destroy();
            }
        } else {
            if (model) {
                model.version = version;
                model.set(data);
            } else {
                model = new this.model(data);
                model.id = id;
                model.version = version;
                this.add(model);
            }
        }
    },

    local_data: function(id) {
        var model = this.get(id);
        if (model) {
            return model.toJSON();
        }
        return null;
    },
});

Backbone.sync = function(method, model, options) {
    if (!model) return;
    var S4 = function() {
        return (((1 + Math.random()) * 0x10000) | 0).toString(16).substring(1);
    };

    var bucket = model.collection && model.collection.bucket;
    if (!bucket) return;

    var isModel = !(typeof model.isNew === 'undefined');
    if (isModel) {
        if (model.isNew()) {
            model.id = S4()+S4()+S4()+S4()+S4();
            model.trigger("change:id", model, model.collection, {});
        }

        switch (method) {
            case "create"   :
            case "update"   : bucket.update(model.id, model.toJSON()); options.success(); break;
            case "delete"   : bucket.update(model.id, null); options.success(); break;
        }
    }
};