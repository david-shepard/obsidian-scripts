<%*
// Converts list of Steam games in markdown format to
// list of games with markdown links to their respective Steam pages


// get highlighted list of games
const noteContent = tp.file.selection();

// replace first '- ' if list element
const games = noteContent.split('\n').map(e=>e.replace('-','').trim()).filter(Boolean)

const results = [];
for (const game of games) {
  const steamURL = `https://store.steampowered.com/search/suggest?term=${encodeURIComponent(game)}&f=games&f=json&cc=SE&realm=1&l=english&use_search_spellcheck=1`
  // check if it's already a markdown url
  if (game.startsWith('[')) {
    console.log(`${game} is already a markdown link`)
    results.push(`- ${game}`)
    continue;
  }
  const resp = await tp.web.request(steamURL)
  results.push(getMarkdownLink(resp, game))
}

function getMarkdownLink(gameJSON, gameFallback) {
  // ie. {id: '1296360', type: 'game', name: 'Archvale'}
  // const appID = gameJSON?.[0] ?? gameFallback
  if (gameJSON && gameJSON[0]) {
    const gameObj = gameJSON[0]
    return `- [${gameObj.name}](https://store.steampowered.com/app/${gameObj.id})`
  } else {
  	return `- ${gameFallback}`
  }
}

return results.join("\n")

//return noteContent
%>
