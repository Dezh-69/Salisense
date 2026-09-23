$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Open("c:\Users\Gervyn\OneDrive\Desktop\SaliSense\PRD.docx")
$doc.SaveAs([ref]"c:\Users\Gervyn\OneDrive\Desktop\SaliSense\PRD.txt", [ref]2)
$doc.Close()
$word.Quit()
