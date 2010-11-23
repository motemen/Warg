<html>
<head>
  <title>Warg Control Center</title>
  <style type="text/css">
body {
  background: #333;
  color: #FFF;
  text-shadow: 2px 2px 1px #444;
}
table {
  width: 100%;
}
td, th {
  padding: 0.3em;
  font-size: small;
}
th {
  background-color: #444;
}
div.progress-container {
  border: 1px solid #BBB;
  width: 200px;
  height: 1em;
}
div.progress {
  background-color: #555;
  height: 100%;
}
  </style>
</head>
<body>
  <h1>Warg Control Center</h1>
? require Data::Dumper;
? local %_ = @_;
? my $result = $_{result};

? if (my $jobs = $result->{result}->{jobs}) {
  <h2>Jobs</h2>
  <table>
    <tr>
      <th>Name</th>
      <th>URL</th>
      <th>Filename</th>
      <th>Status</th>
      <th>Progress</th>
    </tr>
?   for my $job (@$jobs) {
    <tr>
      <td><?= $job->{name} ?></td>
      <td><?= $job->{url} ?></td>
      <td><?= $job->{filename} ?></td>
      <td><?= $job->{status} ?></td>
      <td>
        <?= $job->{formatted_progress} ?>
        <div class="progress-container">
          <div class="progress" style="width: <?= $job->{progress} * 100 ?>%"></div>
        </div>
      </td>
    </tr>
?   }
  </table>
? }

<h2>Debug</h2>
<pre style="background-color: #444; padding: 0.5em; font-size: 90%"><?= Data::Dumper->new([ $result ], [ 'result' ])->Indent(1)->Dump ?></pre>

</body>
</html>
