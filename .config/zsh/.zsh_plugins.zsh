fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-peterhurford-SLASH-up.zsh )
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-peterhurford-SLASH-up.zsh/up.plugin.zsh
fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-rummik-SLASH-zsh-tailf )
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-rummik-SLASH-zsh-tailf/tailf.plugin.zsh
fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-mattmc3-SLASH-zman )
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-mattmc3-SLASH-zman/zman.plugin.zsh
fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-agkozak-SLASH-zsh-z )
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-agkozak-SLASH-zsh-z/zsh-z.plugin.zsh
source $ZDOTDIR/.aliases
fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-romkatv-SLASH-powerlevel10k )
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-romkatv-SLASH-powerlevel10k/powerlevel10k.zsh-theme
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-romkatv-SLASH-powerlevel10k/powerlevel9k.zsh-theme
export PATH="/home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-romkatv-SLASH-zsh-bench:$PATH"
fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-getantidote-SLASH-use-omz )
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-getantidote-SLASH-use-omz/antidote-use-omz.plugin.zsh
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-getantidote-SLASH-use-omz/use-omz.plugin.zsh
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh/lib/clipboard.zsh
fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh/plugins/copybuffer )
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh/plugins/copybuffer/copybuffer.plugin.zsh
fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh/plugins/copyfile )
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh/plugins/copyfile/copyfile.plugin.zsh
fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh/plugins/copypath )
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh/plugins/copypath/copypath.plugin.zsh
fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh/plugins/extract )
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh/plugins/extract/extract.plugin.zsh
fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh/plugins/magic-enter )
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh/plugins/magic-enter/magic-enter.plugin.zsh
fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh/plugins/fancy-ctrl-z )
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh/plugins/fancy-ctrl-z/fancy-ctrl-z.plugin.zsh
fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-belak-SLASH-zsh-utils/history )
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-belak-SLASH-zsh-utils/history/history.plugin.zsh
fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-belak-SLASH-zsh-utils/utility )
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-belak-SLASH-zsh-utils/utility/utility.plugin.zsh
fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-belak-SLASH-zsh-utils/editor )
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-belak-SLASH-zsh-utils/editor/editor.plugin.zsh
if ! (( $+functions[zsh-defer] )); then
  fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-romkatv-SLASH-zsh-defer )
  source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-romkatv-SLASH-zsh-defer/zsh-defer.plugin.zsh
fi
fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-zdharma-continuum-SLASH-fast-syntax-highlighting )
zsh-defer source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-zdharma-continuum-SLASH-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-zsh-users-SLASH-zsh-completions/src )
fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-belak-SLASH-zsh-utils/completion )
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-belak-SLASH-zsh-utils/completion/completion.plugin.zsh
fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-zsh-users-SLASH-zsh-autosuggestions )
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-zsh-users-SLASH-zsh-autosuggestions/zsh-autosuggestions.plugin.zsh
fpath+=( /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-zsh-users-SLASH-zsh-history-substring-search )
source /home/lykrin/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-zsh-users-SLASH-zsh-history-substring-search/zsh-history-substring-search.plugin.zsh
