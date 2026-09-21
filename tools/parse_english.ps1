# Parses the 7 CDS English *_Solved_*.docx sources into per-section JSON files
# under docs/data/. Repeatable: re-run whenever a source file changes.
# No Python/Node needed - reads word/document.xml from each .docx (a zip) directly.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=Split-Path $PSScriptRoot -Parent
$dir="$root\sources"
$dataDir="$root\docs\data"

$files=@(
 'CDS_English_Grammar_Solved_2016-2017.docx',
 'CDS_English_Grammar_Solved_2018-2020.docx',
 'CDS_English_Grammar_Solved_2021-2023.docx',
 'CDS_English_Grammar_Solved_2024-2026.docx',
 'CDS_English_Comprehension_Ordering_Solved_2016-2017.docx',
 'CDS_English_Comprehension_Ordering_Solved_2018-2020.docx',
 'CDS_English_Comprehension_Ordering_Solved_2024-2026.docx'
)

$script:records = New-Object System.Collections.ArrayList
$script:dropLog  = New-Object System.Collections.ArrayList
$script:paperCounts = @{}

function Get-Paras($path){
  $zip=[System.IO.Compression.ZipFile]::OpenRead($path)
  $entry=$zip.Entries | Where-Object { $_.FullName -eq 'word/document.xml' }
  $sr=New-Object System.IO.StreamReader($entry.Open(),[System.Text.Encoding]::UTF8)
  $xml=$sr.ReadToEnd(); $sr.Close(); $zip.Dispose()
  $out=New-Object System.Collections.ArrayList
  foreach($m in [regex]::Matches($xml,'<w:p[ >].*?</w:p>')){
    $p=$m.Value
    $styleM=[regex]::Match($p,'<w:pStyle w:val="([^"]+)"')
    $style= if($styleM.Success){$styleM.Groups[1].Value}else{'N'}
    $texts=[regex]::Matches($p,'<w:t[^>]*>(.*?)</w:t>') | ForEach-Object { $_.Groups[1].Value }
    $text=($texts -join '')
    $text=$text -replace '&amp;','&' -replace '&lt;','<' -replace '&gt;','>' -replace '&quot;','"' -replace '&apos;',"'" -replace '&#39;',"'"
    # site rule: no em-dashes anywhere. Convert em-dash to a spaced hyphen (meaning-preserving),
    # then tidy any doubled spaces it creates.
    $text=$text -replace '—',' - ' -replace '  +',' '
    [void]$out.Add([pscustomobject]@{style=$style;text=$text.Trim()})
  }
  return $out
}

function Normalize($h3){
  $n=$h3
  $n=$n -replace '\s*\(\d+\)\s*$',''
  $n=$n -replace '\s*\(Q[^)]*\)',''
  $n=$n -replace '\s*\(selected[^)]*\)',''
  $n=$n -replace '\s*\(did[^)]*\)',''
  $n=$n -replace '\s*[-–]\s*Passage.*$',''
  $n=$n -replace '\s*[-–]\s*fill in the blank.*$',''
  $n=$n -replace '\s*[-–]\s*(part of speech|identify).*$',''
  $n=$n -replace '\s*[-–]\s*Active.*$',''
  return $n.Trim()
}

# returns [tile, subtopic, topicFamilyLabel, isPassage]
function MapType($n){
  switch -regex ($n){
    '^Spotting Error'           {return @('Spotting Errors','','Grammar & Usage',$false)}
    '^Fill in the Blank'        {return @('Fill in the Blanks','','Grammar & Usage',$false)}
    '^Sentence Improvement'     {return @('Sentence Improvement','','Grammar & Usage',$false)}
    '^Completion of Sentence'   {return @('Sentence Completion','','Grammar & Usage',$false)}
    '^Sentence Completion'      {return @('Sentence Completion','','Grammar & Usage',$false)}
    '^Parts of Speech'          {return @('Parts of Speech / Word Classes','Parts of Speech','Grammar & Usage',$false)}
    '^Word Classes'             {return @('Parts of Speech / Word Classes','Word Classes','Grammar & Usage',$false)}
    '^Preposition'              {return @('Prepositions & Determiners','','Grammar & Usage',$false)}
    '^Sentence Co-relationship' {return @('Other Grammar','Sentence Co-relationship','Grammar & Usage',$false)}
    '^Correlating Sentences'    {return @('Other Grammar','Sentence Co-relationship','Grammar & Usage',$false)}
    '^Spelling'                 {return @('Other Grammar','Spelling','Grammar & Usage',$false)}
    '^Reported Speech'          {return @('Other Grammar','Reported Speech','Grammar & Usage',$false)}
    '^Transformation'           {return @('Other Grammar','Transformation of Sentences','Grammar & Usage',$false)}
    '^Passive Voice'            {return @('Other Grammar','Voice (Active/Passive)','Grammar & Usage',$false)}
    '^Voice'                    {return @('Other Grammar','Voice (Active/Passive)','Grammar & Usage',$false)}
    '^Use of Phrasal Verbs'     {return @('Other Grammar','Use of Phrasal Verbs','Grammar & Usage',$false)}
    '^Reading Comprehension'    {return @('Reading Comprehension','','Comprehension & Ordering',$true)}
    '^Ordering of Sentences'    {return @('Ordering of Sentences','','Comprehension & Ordering',$false)}
    '^Ordering of Words'        {return @('Ordering of Words','','Comprehension & Ordering',$false)}
    '^Cloze'                    {return @('Cloze','Cloze','Comprehension & Ordering',$true)}
    '^Selecting Words'          {return @('Cloze','Selecting Words','Comprehension & Ordering',$true)}
    default { return @($null,$null,$null,$false) }
  }
}

$tileKey=@{
 'Spotting Errors'='spotting-errors';'Fill in the Blanks'='fill-blanks';'Sentence Improvement'='sentence-improvement';
 'Sentence Completion'='sentence-completion';'Parts of Speech / Word Classes'='parts-of-speech';
 'Prepositions & Determiners'='prepositions-determiners';'Other Grammar'='other-grammar';
 'Reading Comprehension'='reading-comprehension';'Ordering of Sentences'='ordering-sentences';
 'Ordering of Words'='ordering-words';'Cloze'='cloze'
}

function Finalize-Q($q){
  if($null -eq $q){return}
  $opts=@((''+$q.opt['a']),(''+$q.opt['b']),(''+$q.opt['c']),(''+$q.opt['d']))
  $nonEmpty=($opts | Where-Object { $_ -ne '' }).Count
  $hasAns = $q.answer -and (@('a','b','c','d') -contains $q.answer)
  $ansIdx = @('a','b','c','d').IndexOf(''+$q.answer)
  $ansOptPresent = ($ansIdx -ge 0) -and ($opts[$ansIdx] -ne '')
  $hasBody = ($q.stem -ne '') -or ($q.subs.Count -gt 0)
  if($nonEmpty -ge 3 -and $hasAns -and $ansOptPresent -and $hasBody){
    $rec=[ordered]@{
      id=$q.id; subject=$q.tile; topic=$q.topicVal; subtopic=$q.subtopic; topicOriginal=$q.fineType
      year=$q.year; session=$q.sess; paper=$q.paper; qno=$q.qno; ref=$q.ref
      directions=$q.directions; passageId=$q.passageId; passageText=$q.passageText
      stem=$q.stem; subs=@($q.subs); options=$opts; answer=$q.answer; explanation=$q.explanation
    }
    [void]$script:records.Add($rec)
    if($script:paperCounts.ContainsKey($q.pkey)){ $script:paperCounts[$q.pkey].parsed++ }
  } else {
    $r=@(); if($nonEmpty -lt 3){$r+="opts=$nonEmpty"}; if(-not $hasAns){$r+="noans"}; if(-not $ansOptPresent -and $hasAns){$r+="ansEmptyOpt"}; if(-not $hasBody){$r+="nobody"}
    [void]$script:dropLog.Add(('{0} Q{1} [{2}] {3}' -f $q.paper,$q.qno,$q.fineType,($r -join ',')))
    if($script:paperCounts.ContainsKey($q.pkey)){ $script:paperCounts[$q.pkey].dropped++ }
  }
}

foreach($fn in $files){
  $path=Join-Path $dir $fn
  $paras=Get-Paras $path
  $year=0;$sess='';$paper='';$pkey=''
  $tile=$null;$subtopic='';$topicVal='';$isPassage=$false;$fineType='';$rmin=0;$rmax=9999;$directions='';$inSection=$false
  $passageId='';$passageText=New-Object System.Collections.ArrayList;$passageCounter=0
  $cur=$null

  foreach($pr in $paras){
    $t=$pr.text
    if($pr.style -eq 'Heading1'){ if($t -match '^\d{4}$'){$year=[int]$t}; continue }
    if($pr.style -eq 'Heading2'){
      Finalize-Q $cur; $cur=$null
      $sm=[regex]::Match($t,'CDS\s*([12])')
      $sess= if($sm.Success -and $sm.Groups[1].Value -eq '2'){'II'}else{'I'}
      $paper=('CDS {0}-{1}' -f $year,$sess); $pkey=$paper
      if(-not $script:paperCounts.ContainsKey($pkey)){ $script:paperCounts[$pkey]=[pscustomobject]@{parsed=0;dropped=0} }
      $passageCounter=0;$inSection=$false;$tile=$null
      continue
    }
    if($pr.style -eq 'Heading3'){
      Finalize-Q $cur; $cur=$null
      if($t -match 'omitted'){ $inSection=$false;$tile=$null; continue }
      $rm=[regex]::Match($t,'\(Q(\d+)\s*[-–]\s*(\d+)\)')
      if($rm.Success){ $rmin=[int]$rm.Groups[1].Value; $rmax=[int]$rm.Groups[2].Value } else { $rmin=0;$rmax=9999 }
      $fineType=Normalize $t
      $map=MapType $fineType
      if($null -eq $map[0]){ $inSection=$false;$tile=$null; continue }
      $tile=$map[0];$subtopic=$map[1];$topicVal=$map[2];$isPassage=$map[3]
      $directions='';$inSection=$true
      $passageText=New-Object System.Collections.ArrayList
      if($isPassage){ $passageCounter++; $passageId=('{0}-P{1}' -f ($paper -replace '\s',''),$passageCounter) } else { $passageId='' }
      continue
    }
    if(-not $inSection -or $t -eq ''){ continue }
    if($t -match '^Directions:'){ $directions=($t -replace '^Directions:\s*',''); continue }
    if($t -match '^Passage\b' -or $t -eq 'Passage'){ continue }

    $qm=[regex]::Match($t,'^(\d+)\.\s*(.*)$')
    if($qm.Success -and ([int]$qm.Groups[1].Value) -ge $rmin -and ([int]$qm.Groups[1].Value) -le $rmax){
      Finalize-Q $cur
      $num=[int]$qm.Groups[1].Value
      $ptext=''; if($isPassage){ $ptext=($passageText -join "`n`n") }
      $cur=[pscustomobject]@{
        id=('eng-{0}-{1}-{2}-q{3}' -f $year,$sess,$tileKey[$tile],$num)
        tile=$tile; topicVal=$topicVal; subtopic=$subtopic; fineType=$fineType
        year=$year; sess=$sess; paper=$paper; qno=$num
        ref=('CDS {0}-{1}, Q.{2}' -f $year,$sess,$num)
        directions=$directions; passageId=$passageId; passageText=$ptext
        stem=$qm.Groups[2].Value; subs=(New-Object System.Collections.ArrayList)
        opt=@{}; answer=''; explanation=''; pkey=$pkey
      }
      continue
    }

    if($null -ne $cur){
      if($t -match '^(S1|S6|[PQRS]):\s'){ [void]$cur.subs.Add($t); continue }
      if($t -match '^Proper sequence:'){ continue }
      $om=[regex]::Match($t,'^\(([a-d])\)\s*(.*)$')
      if($om.Success){ $cur.opt[$om.Groups[1].Value]=$om.Groups[2].Value; continue }
      if($t -match '^Answer:'){
        $lm=[regex]::Match($t,'\(([a-d])\)'); if(-not $lm.Success){ $lm=[regex]::Match($t,'part\s+([a-d])\b') }
        if($lm.Success){ $cur.answer=$lm.Groups[1].Value }; continue
      }
      if($t -match '^Why:\s*(.*)$'){ $cur.explanation=($t -replace '^Why:\s*',''); continue }
      if($t -match 'Note:'){ continue }
      if($cur.opt.Count -eq 0 -and -not ($t -match '^\(')){ if($cur.stem -eq ''){$cur.stem=$t}else{$cur.stem=$cur.stem+' '+$t} }
      continue
    } else {
      if($isPassage){ [void]$passageText.Add($t) }
      continue
    }
  }
  Finalize-Q $cur; $cur=$null
}

# dedup by id: last (comprehension) copy wins over any grammar-file duplicate
$seen=[ordered]@{}; $dupCount=0
foreach($r in $script:records){ if($seen.Contains($r['id'])){$dupCount++}; $seen[$r['id']]=$r }
$deduped=@($seen.Values)

# bucket by tile and write one file per section
if(-not (Test-Path $dataDir)){ New-Item -ItemType Directory -Path $dataDir | Out-Null }
$enc=New-Object System.Text.UTF8Encoding($false)
$byTile=@{}
foreach($r in $deduped){ $k=$tileKey[$r['subject']]; if(-not $byTile.ContainsKey($k)){$byTile[$k]=New-Object System.Collections.ArrayList}; [void]$byTile[$k].Add($r) }
foreach($k in $byTile.Keys){
  $arr=@($byTile[$k] | Sort-Object @{e={$_['passageId']}},@{e={[int]$_['year']}},@{e={$_['session']}},@{e={[int]$_['qno']}})
  $json=$arr | ConvertTo-Json -Depth 6
  [System.IO.File]::WriteAllText((Join-Path $dataDir ($k+'.json')),$json,$enc)
}

Write-Host ("UNIQUE questions: {0}   dropped(defective): {1}   duplicates removed: {2}" -f $deduped.Count,$script:dropLog.Count,$dupCount)
Write-Host "`n==== PER TILE (file : count) ===="
foreach($k in ($byTile.Keys | Sort-Object { -$byTile[$_].Count })){ "{0,-26} {1}" -f ($k+'.json'),$byTile[$k].Count }
Write-Host "`nData files written to docs\data\. Now run tools\build_index.ps1 to rebuild the manifest."
