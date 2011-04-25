%pkg-config glib-2.0
%pkg-config gtk+-2.0
%pkg-config gthread-2.0

%include gdk-pixbuf/gdk-pixbuf.h
%name bgpixbuf
%{

typedef struct {
	GThread *thread;
	GdkPixbuf *pixbuf;
	GMutex *mutex;
	GError *error;
	char *filename;
} LoaderStruct;

static LoaderStruct *
loader_unwrap(VALUE obj)
{
	LoaderStruct *loader;
	//Check_Type(obj, T_OBJECT);
	Data_Get_Struct(obj, LoaderStruct, loader);
	return loader;
}

static void loader_destroy
(LoaderStruct *loader)
{
	/* Kill it */
	if (loader->mutex)
		g_mutex_free(loader->mutex);

	if (loader->pixbuf)
		g_object_unref(loader->pixbuf);
	
	if (loader->filename)
		g_free(loader->filename);

	g_free(loader);
}

static void loader_mark
(LoaderStruct *loader)
{
	/* Mark nothing... */
}

static LoaderStruct *
new_loader() 
{
	LoaderStruct *loader;

	loader = ALLOC(LoaderStruct);

	loader->thread = NULL;
	loader->mutex = g_mutex_new();
	loader->filename = NULL;
	loader->error = NULL;
	loader->pixbuf = NULL;
	
	return loader;
}

#define assert(x) if (!(x)) { rb_raise(rb_eRuntimeError, "Assertion: '%s' failed.", #x); }

static void 
load_pixbuf(LoaderStruct *loader) {
	g_mutex_lock(loader->mutex);
	loader->pixbuf = gdk_pixbuf_new_from_file(loader->filename, &(loader->error));
	g_mutex_unlock(loader->mutex);
}

static inline VALUE 
unref_pixbuf(GdkPixbuf *pixbuf)
{
	volatile VALUE pb = Qnil;
	
	pb = GOBJ2RVAL(pixbuf);
	
	gdk_pixbuf_unref(pixbuf);
	
	return pb;
}


%}

%map VALUE > LoaderStruct* : loader_unwrap(%%)
%map VALUE > GdkPixbuf* : GDK_PIXBUF(RVAL2GOBJ(%%))
%map GdkPixbuf* > VALUE : GOBJ2RVAL(GDK_PIXBUF(%%))
%map unref_pixbuf > VALUE : unref_pixbuf((%%))


module BgPixbuf
	class Loader
		pre_func LoaderStruct *_self = loader_unwrap(self);

		def self.__alloc__
			return Data_Wrap_Struct(self, loader_mark, loader_destroy, new_loader());
		end

		def initialize(char *pixbuf)
			GError *error = NULL;
			_self->filename = g_strdup(pixbuf);
			_self->thread   = g_thread_create((load_pixbuf), _self, FALSE, &error);
			if (error)
				RAISE_GERROR(error);
		end

		def GdkPixbuf*:pixbuf
			if (g_mutex_trylock(_self->mutex))
			{
				g_mutex_unlock(_self->mutex);
				if (_self->error) {
					RAISE_GERROR(_self->error);
				}
				return _self->pixbuf;
			}
			return NULL;
		end
	end
end


