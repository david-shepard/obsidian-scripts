noteContent = tp.file.selection();

//get array of lines
lines = noteContent.split('\n')

// filter out empty lines
const newLines = lines.
  map(elem => elem.trim()).
  filter(elem => elem.length > 0)

return newLines.join('\n')
