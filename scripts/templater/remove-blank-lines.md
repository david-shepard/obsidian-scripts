```md
<%*
// Save this in `templater` Folder location as ie. `Remove empty lines.md`
// Use via "Templater: Open Insert Templater Modal -> Remove empty lines" 

// highlighted selection
const noteContent = tp.file.selection();

//get array of lines
const linesOrig = noteContent.split('\n')

// filter out empty lines, using `flatMap` avoid the need for filter step
const newLines = linesOrig.flatMap((line) => {
    if (line.trim().length > 0) return line
    return []
})

return newLines.join('\n')
%>
```