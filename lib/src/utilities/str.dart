
extension StringEx on String {
  List<String> splitN(String sep, int n) {
    if (n == 0) return <String>[];
    var s = this;
    if (sep == '') {
      if (n < 0 || n > length) {
        n = length;
      }

      var r = List<String>.filled(n, '');
      for (var i = 0; i < n - 1; i++) {
        r[i] = s[i];
      }
      if (n > 0) r[n - 1] = s.substring(n - 1);
      return r;
    }

    if (n < 0) {
      n = count(sep) + 1;
    }

    var r = List<String>.filled(n, '');
    n--;
    var i = 0;
    while (i < n) {
      var m = indexOf(sep);
      if (m < 0) break;

      r[i] = s.substring(0, m);
      s = s.substring(m + sep.length);
      i++;
    }
    r[i] = s;
    return r.sublist(0, i + 1);
  }

  int count(String sep) {
    if (sep.isEmpty) return length + 1;

    var j = 0;
    var s = this;
    while (true) {
      var i = s.indexOf(sep);
      if (i == -1) return j;
      j++;
      s = s.substring(i + sep.length);
    }
  }
}
