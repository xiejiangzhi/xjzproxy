#include "ruby.h"
#include "stdio.h"

const VALUE zero = INT2NUM(0);
const VALUE dlen = INT2NUM(4);


VALUE take_len(VALUE *str, VALUE len, VALUE fmt) {
  VALUE len_str = rb_funcall(*str, rb_intern("slice!"), 2, zero, len);
  VALUE unpack_ary = rb_funcall(len_str, rb_intern("unpack"), 1, fmt);
  return rb_funcall(unpack_ary, rb_intern("first"), 0);
}

VALUE read_code_path(VALUE path) {
  VALUE Zlib_cls = rb_const_get(rb_cObject, rb_intern("Zlib"));
  VALUE Inflate_cls = rb_const_get(Zlib_cls, rb_intern("Inflate"));
  VALUE data = rb_funcall(rb_cFile, rb_intern("read"), 1, path);
  VALUE rand_len = take_len(&data, INT2NUM(1), rb_str_new_cstr("C"));

  rb_funcall(data, rb_intern("force_encoding"), 1, rb_str_new_cstr("binary"));
  rb_funcall(data, rb_intern("slice!"), 2, zero, rand_len);
  rb_funcall(data, rb_intern("slice!"), 2, INT2NUM(-NUM2INT(rand_len)), rand_len);
  return rb_funcall(Inflate_cls, rb_intern("inflate"), 1, data);
}

VALUE take_data(VALUE *str) {
  VALUE len = take_len(str, dlen, rb_str_new_cstr("N"));
  return rb_funcall(*str, rb_intern("slice!"), 2, zero, len);
}

VALUE get_vm_iseq_cls() {
  VALUE rbvm = rb_const_get(rb_cObject, rb_intern("RubyVM"));
  return rb_const_get(rbvm, rb_intern("InstructionSequence"));
}

VALUE parse_code(VALUE *code_str) {
  VALUE r = rb_hash_new();
  VALUE vmiseq_cls = get_vm_iseq_cls();

  while (NUM2INT(rb_str_length(*code_str)) > 0) {
    VALUE k = take_data(code_str);
    VALUE v = rb_funcall(
      vmiseq_cls, rb_intern("load_from_binary"), 1, take_data(code_str)
    );
    rb_hash_aset(r, k, v);
  }
  return r;
}

VALUE init_app(VALUE self) {
  VALUE root_path = rb_gv_get("$root");
  VALUE data_path = rb_file_expand_path(rb_str_new_cstr("./data"), root_path);

  VALUE code_str = read_code_path(data_path);
  rb_funcall(code_str, rb_intern("force_encoding"), 1, rb_str_new_cstr("binary"));
  VALUE code_hash = parse_code(&code_str);
  rb_gv_set("$ISEQS", code_hash);
  return self;
}

VALUE load_file(VALUE self, VALUE path) {
  VALUE iseqs = rb_gv_get("$ISEQS");
  VALUE iseq = rb_hash_aref(iseqs, path);

  if (rb_gv_get("$ISEQS_DEBUG") != Qnil && iseq == Qnil) {
    printf("[ERR] Failed to load path %s\n", RSTRING_PTR(path));
  }

  if (iseq != Qnil) {
    rb_funcall(iseq, rb_intern("eval"), 0);
    rb_hash_delete(iseqs, path);
    
    return Qtrue;
  } else {
    return Qfalse;
  }
}

VALUE run_app(VALUE self) {
  load_file(self, rb_str_new_cstr("loader.rb"));
  load_file(self, rb_str_new_cstr("boot.rb"));
  return self;
}

void Init_loader() {
  rb_require("zlib");
  VALUE App = rb_define_module("Xjz");
  rb_define_singleton_method(App, "init", init_app, 0);
  rb_define_singleton_method(App, "run", run_app, 0);
  rb_define_singleton_method(App, "_load_file", load_file, 1);
}

