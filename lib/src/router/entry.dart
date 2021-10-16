part of 'router.dart';


enum NodeType {
  static,  /// 普通节点
  root,    /// 根节点
  param,   /// 有参数的节点  如 /user/:id
  catchAll /// 有*匹配的节点 如 /article/*key
}

class _Node {
  /// 当前节点路径
  String path = '';

  /// 子节点是否包含通配符（*或者:）即包含 param、catchAll两种类型
  bool wildChild = false;

  NodeType nType = NodeType.static;

  /// 所有子节点 path 的第一个字符组成的字符串
  String indices = '';

  /// 当前节点及子孙节点的实际路由数量
  int priority = 0;
  List<_Node> children = []..length=0;
  Function? handle;

  Middleware? middleware;

  _Node(this.path, this.wildChild, this.nType, this.indices, this.children,
      this.handle, this.priority,this.middleware);

  _Node.Empty();

  static void addRoute(_Node n, String path, Function handle,Middleware? middleware) {
    var fullPath = path;
    n.priority++;

    if (n.path.isEmpty && n.indices.isEmpty) {
      insertChild(n,path, fullPath, handle,middleware);
      n.nType = NodeType.root;
      return;
    }

    walk:
    while (true) {
      // Find the longest common prefix.
      var i = longestCommonPrefix(path, n.path);

      if (i < n.path.length) {
        var child = _Node(n.path.substring(i), n.wildChild, NodeType.static,
            n.indices, n.children, n.handle, n.priority - 1,n.middleware);

        n.children = [child];
        n.indices = n.path[i];
        n.path = path.substring(0, i);
        n.handle = null;
        n.middleware = null;
        n.wildChild = false;
      }

      // Make new node a child of this node
      if (i < path.length) {
        path = path.substring(i);
        if (n.wildChild) {
          n = n.children[0];
          n.priority++;

          if (path.length >= n.path.length &&
              n.path == path.substring(0, n.path.length) &&
              n.nType != NodeType.catchAll &&
              (n.path.length >= path.length || path[n.path.length] == '/')) {
            continue walk;
          } else {
            // 通配符冲突
            var pathSeg = path;
            if (n.nType != NodeType.catchAll) {
              pathSeg = pathSeg.splitN('/', 2)[0];
            }
            var prefix =
                fullPath.substring(0, fullPath.indexOf(pathSeg)) + n.path;
            throw Exception(
                '"$pathSeg" in new path "$fullPath" conflicts with existing wildcard "${n.path}" in existing prefix "$prefix"');
          }
        }

        var idxc = path[0];

        if (n.nType == NodeType.param &&
            idxc == '/' &&
            n.children.length == 1) {
          n = n.children[0];
          n.priority++;
          continue walk;
        }

        //判断当前节点的 indices 索引中是否存在当前path的首字母
        for (var j = 0; j < n.indices.length; j++) {
          var c = n.indices[j];
          if (c == idxc) {
            var k = incrementChildPrio(n,j);
            n = n.children[k];
            continue walk;
          }
        }

        if (idxc != ':' && idxc != '*') {
          n.indices += idxc;
          var child = _Node.Empty();
          n.children.add(child);
          incrementChildPrio(n,n.indices.length - 1);
          n = child;
        }
        insertChild(n,path, fullPath, handle,middleware);
        return;
      }

      if (n.handle != null) {
        throw Exception('a handle is already registered for path "$fullPath"');
      }
      n.handle = handle;
      n.middleware = middleware;
      return;
    }
  }

  static void insertChild(_Node n,String path, String fullPath, Function handle,Middleware? middleware) {
    while(true){
      // Find prefix until first wildcard
      var r = findWildcard(path);
      var wildcard = r[0] as String;
      var i = r[1]  as int;
      var valid = r[2]  as bool;

      if(i<0) break;

      if (!valid) {
        throw Exception(
            'only one wildcard per path segment is allowed, has: "$wildcard" in path "$fullPath"');
      }

      if(wildcard.length < 2){
        throw Exception(
            'wildcards must be named with a non-empty name in path "$fullPath"');
      }

      // Check if this node has existing children which would be
      // unreachable if we insert the wildcard here
      if (n.children.isNotEmpty) {
        throw Exception(
            'wildcard segment "$wildcard" conflicts with existing children in path "$fullPath"');
      }

      if (wildcard[0] == ':') {
        if (i > 0) {
          // Insert prefix before the current wildcard
          n.path = path.substring(0, i);
          path = path.substring(i);
        }

        n.wildChild = true;
        var child = _Node.Empty();
        child.nType = NodeType.param;
        child.path = wildcard;
        n.children = [child];
        n = child;
        n.priority++;

        // If the path doesn't end with the wildcard, then there
        // will be another non-wildcard subpath starting with '/'
        if(wildcard.length < path.length){
          path = path.substring(wildcard.length);
          var child = _Node.Empty();
          child.priority=1;
          n.children = [child];
          n = child;
          continue;
        }

        // Otherwise we're done. Insert the handle in the new leaf
        n.handle = handle;
        n.middleware = middleware;
        return;
      }

      // catchAll
      if(i+wildcard.length != path.length){
        throw Exception(
            'catch-all routes are only allowed at the end of the path in path  "$fullPath"');
      }

      if(n.path.isNotEmpty && n.path[n.path.length-1] == '/'){
        throw Exception(
            'catch-all conflicts with existing handle for the path segment root in path "$fullPath"');
      }

      // Currently fixed width 1 for '/'
      i --;
      if(path[i] != '/'){
        throw Exception('no / before catch-all in path "$fullPath"');
      }

      n.path = path.substring(0,i);

      // First node: catchAll node with empty path
      var child = _Node.Empty();
      child.wildChild=true;
      child.nType = NodeType.catchAll;
      n.children = [child];
      n.indices = '/';
      n = child;
      n.priority++;

      // Second node: node holding the variable
      child = _Node.Empty();
      child.path=path.substring(i);
      child.nType=NodeType.catchAll;
      child.handle = handle;
      child.middleware = middleware;
      child.priority=1;
      n.children=[child];
      return;
    }
    // If no wildcard was found, simply insert the path and handle
    n.path = path;
    n.handle = handle;
    n.middleware = middleware;
  }

  // Search for a wildcard segment and check the name for invalid characters.
  // Returns -1 as index, if no wildcard was found.
  static List findWildcard(String path){
    for(var start =0;start<path.length;start++){
      var c = path[start];
      // A wildcard starts with ':' (param) or '*' (catch-all)
      if(c != ':' && c != '*') continue;
      // Find end and check for invalid characters
      var valid = true;
      var p = path.substring(start+1);
      for(var end =0;end < p.length;end++){
        var c = p[end];
        switch (c) {
          case '/':
            return [path.substring(start, start + 1 + end), start, valid];
          case ':':
          case '*':
            valid = false;
        }
      }
      return [path.substring(start),start,valid];
    }
    return ['',-1,false];
  }

  static List getValue(_Node n, String path) {
    Map<String, String>? params;
    var tsr = false;
    Function? handle;
    Middleware? middleware;
    walk:
    while (true) {
      var prefix = n.path;
      if (path.length > prefix.length) {
        if (path.substring(0, prefix.length) == prefix) {
          path = path.substring(prefix.length);
          // If this node does not have a wildcard (param or catchAll)
          // child, we can just look up the next child node and continue
          // to walk down the tree
          if (!n.wildChild) {
            var idxc = path[0];
            for (var i = 0; i < n.indices.length; i++) {
              var c = n.indices[i];
              if (c == idxc) {
                n = n.children[i];
                continue walk;
              }
            }
            // Nothing found.
            // We can recommend to redirect to the same URL without a
            // trailing slash if a leaf exists for that path.
            tsr = (path == '/' && n.handle != null);
            return [handle, params, tsr,middleware];
          }

          // Handle wildcard child
          n = n.children[0];
          switch (n.nType) {
            case NodeType.param:
            // Find param end (either '/' or path end)
              var end = 0;
              while (end < path.length && path[end] != '/') {
                end++;
              }

              // Save param value
              params ??= <String, String>{};
              params[n.path.substring(1)] = path.substring(0, end);

              // We need to go deeper!
              if (end < path.length) {
                if (n.children.isNotEmpty) {
                  path = path.substring(end);
                  n = n.children[0];
                  continue walk;
                }

                tsr = path.length == end + 1;
                return [handle, params, tsr,middleware];
              }

              handle = n.handle;
              middleware = n.middleware;
              if (handle != null) {
                return [handle, params, tsr,middleware];
              } else if (n.children.length == 1) {
                // No handle found. Check if a handle for this path + a
                // trailing slash exists for TSR recommendation
                n = n.children[0];
                tsr = (n.path == '/' && n.handle != null) ||
                    (n.path == '' && n.indices == '/');
              }
              return [handle, params, tsr,middleware];
            case NodeType.catchAll:
              params ??= <String, String>{};
              params[n.path.substring(2)] = path;
              handle = n.handle;
              middleware = n.middleware;
              return [handle, params, tsr,middleware];
            default:
              throw Exception('invalid node type');
          }
        }
      } else if (path == prefix) {
        // We should have reached the node containing the handle.
        // Check if this node has a handle registered.
        handle = n.handle;
        middleware = n.middleware;
        if (handle != null) return [handle, params, tsr,middleware];

        // If there is no handle for this route, but this route has a
        // wildcard child, there must be a handle for this path with an
        // additional trailing slash
        if (path == '/' && n.wildChild && n.nType != NodeType.root) {
          tsr = true;
          return [handle, params, tsr,middleware];
        }

        // No handle found. Check if a handle for this path + a
        // trailing slash exists for trailing slash recommendation
        for (var i = 0; i < n.indices.length; i++) {
          var c = n.indices[i];
          if (c == '/') {
            n = n.children[i];
            tsr = (n.path.length == 1 && n.handle != null) ||
                (n.nType == NodeType.catchAll && n.children[0].handle != null);
            return [handle, params, tsr,middleware];
          }
        }
        return [handle, params, tsr,middleware];
      }
      // Nothing found. We can recommend to redirect to the same URL with an
      // extra trailing slash if a leaf exists for that path
      tsr = (path == '/') ||
          (prefix.length == path.length + 1 &&
              prefix[path.length] == '/' &&
              path == prefix.substring(0, prefix.length - 1) &&
              n.handle != null);
      return [handle, params, tsr,middleware];
    }
  }

  static int longestCommonPrefix(String a, String b) {
    var i=0;
    var len = min(a.length, b.length);
    while (i < len && a[i] == b[i]) { i++; }
    return i;
  }

  // Increments priority of the given child and reorders if necessary
  static int incrementChildPrio(_Node n,int pos) {
    var cs = n.children;
    cs[pos].priority ++;
    var prio = cs[pos].priority;

    var newPos = pos;
    for(;newPos>0 && cs[newPos-1].priority < prio;newPos--){
      // Swap node positions
      var tmp = cs[newPos-1];
      cs[newPos-1] = cs[newPos];
      cs[newPos] = tmp;
    }

    // Build new index char string
    if(newPos != pos){
      n.indices = n.indices.substring(0, newPos) +
          n.indices.substring(pos, pos + 1) +
          n.indices.substring(newPos, pos) +
          n.indices.substring(pos + 1);
    }
    return newPos;
  }
}


class _NodeResult{
  _NodeResult(this._node,this._params,this._handle,this._middleware);

  final _Node? _node;
  final Map<String,String>? _params;
  final Function? _handle;
  final Middleware? _middleware;
}