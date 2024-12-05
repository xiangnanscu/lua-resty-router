编写一个router:collect_routes(dir)方法, 它递归扫描dir文件夹里面的lua文件,  并尝试把符合路由数据结构的模块转换成统一的路由参数数组`{"/path", view_func, methods}`这种格式, 假设某个模块的文件路径是`dir/foo/bar.lua`, collect_routes函数最终输出的一个路由参数数组routes:
```lua
local route = require('dir/foo/bar.lua')
```
然后`route`有三种类型:
1. 函数或callable table
则执行:
```lua
{ '/foo/bar', route }
```
2. table且第一个元素是string,第二个元素是callabe或string
(1)route[1]的第一个字符是`/`, 则对应:
```lua
{ route[1], route[2], route[3] }
```
(2)route[1]的第一个字符不是`/`, 则对应:
```lua
{ '/foo/bar/'..route[1], route[2], route[3] }
```
3. table且每一个元素都是类型2的那种table, 则遍历该route, 像类型2那样对应每一个元素:
```lua
for _, view in ipairs(route) do
  { view[1], view[2], view[3] }  -- view[1] is not start with /
  { '/foo/bar/'..view[1], view[2], view[3] } -- view[1] is start with /
end
```
4.table且是map类型的, 比如:
```lua
{
  a1 = view1,
  a2 = view2,
}
```
则对应下列元素:
```lua
{ '/foo/bar/a1', view1 }
{ '/foo/bar/a2', view2 }
```
注: 源代码包括注释全用英文, 不要用中文