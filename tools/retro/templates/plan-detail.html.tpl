<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Plan: {{PLAN_SLUG}}</title>
<link rel="stylesheet" href="app.css">
</head>
<body>
<p><a href="index.html">&larr; Back to Dashboard</a></p>
<h1>Plan: {{PLAN_SLUG}}</h1>
<table id="plan-detail-table">
<thead>
<tr>
  <th>Stage</th>
  <th>Agent</th>
  <th>Tokens In</th>
  <th>Tokens Out</th>
  <th>Cache Read</th>
  <th>Cache Creation</th>
  <th>Wall Active (min)</th>
  <th>Turns</th>
  <th>Tool Calls</th>
</tr>
</thead>
<tbody>
{{STAGE_ROWS}}
</tbody>
</table>
<script>
(function() {
  var table = document.getElementById('plan-detail-table');
  var headers = table.querySelectorAll('th');
  var sortDir = {};
  headers.forEach(function(th, idx) {
    th.style.cursor = 'pointer';
    th.addEventListener('click', function() {
      var rows = Array.from(table.tBodies[0].rows);
      sortDir[idx] = sortDir[idx] === 'asc' ? 'desc' : 'asc';
      rows.sort(function(a, b) {
        var av = a.cells[idx] ? a.cells[idx].textContent : '';
        var bv = b.cells[idx] ? b.cells[idx].textContent : '';
        var n = parseFloat(av) - parseFloat(bv);
        var cmp = isNaN(n) ? av.localeCompare(bv) : n;
        return sortDir[idx] === 'asc' ? cmp : -cmp;
      });
      rows.forEach(function(r) { table.tBodies[0].appendChild(r); });
    });
  });
})();
</script>
</body>
</html>
