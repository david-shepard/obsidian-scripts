// common language options
const langOptions = [
    "yaml", 
    "javascript", 
    "python", 
    "dataview", 
    "dataviewjs", 
    "css", 
    "html", 
    "bash", 
    "json", 
    "markdown",
    "Other..."
];

let selectedLang = await tp.system.suggester(langOptions, langOptions);

if (selectedLang === "Other...") {
    selectedLang = await tp.system.prompt("Enter the language name:");
}

const noteContent = tp.file.content
const lines = noteContent.split('\n')
  
// first "```" is always a code block heading
let isCodeBlockHeader = true
const outLines = []

lines.forEach((line,i,arr) => {
  // match codeblock headings
  const match = lines[i].match(/^(\s*)```(.*)$/);
  if (match) {
    if (isCodeBlockHeader) {
      outLines.push('```' + selectedLang)
    } else {
      outLines.push(line)
    }
    // toggle the next code block heading
    isCodeBlockHeader = !isCodeBlockHeader
  } else {
    outLines.push(line)
  }
})

// set note contents to new lines
await tp.app.vault.modify(tp.config.target_file, outLines.join('\n'));
