---
--- bolo-ui data initialization file
---
<%
  def q(s)
    return q.gsub("'", %q(\\\'))
  end
%>
DELETE FROM boards;
<% p('boards', []).each_with_index do |board,i| %>
INSERT INTO boards (link, name, position, code)
  VALUES ('<%= q(board.name) %>', '<%= q(board.link) %>', <%= i %>, '<%= q(board.code) %>');
<% end %>
