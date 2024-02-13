### Source
https://www.atlassian.com/git/tutorials/dotfiles
<br>
https://news.ycombinator.com/item?id=11070797
<br>
https://github.com/Siilwyn/my-dotfiles/tree/master/.my-dotfiles


**1. Create local bare repo**

create new repository on github.com
```bash
git init --bare $HOME/.myconf
echo "alias config='/usr/bin/git --git-dir=$HOME/.myconf/ --work-tree=$HOME'" >> $HOME/.bashrc
. .bashrc
config config --local status.showUntrackedFiles no
config branch -M main
config remote add origin https://github.com/Michail-Sergievsky/dotfiles.git
config remote set-url origin git@github.com:USERNAME/REPOSITORY.git
config push
    OR
config push --set-upstream origin main
    #for first time
```
**2. Use to add,commit,push dotfiles**
```bash
config status
config add .vimrc
config commit -m "Add vimrc"
config add .bashrc
config commit -m "Add bashrc"
config push
```

**3. Restoring on new machine**

Prior to the installation make sure you have committed the alias to your
.bashrc or .zsh:

    alias config='/usr/bin/git --git-dir=$HOME/.myconf/ --work-tree=$HOME'

And that your source repository ignores the folder where you'll clone it,
so that you don't create weird recursion problems:

    echo ".myconf" >> .gitignore

Now clone your dotfiles into a bare repository in a "dot" folder of your $HOME:

    git clone --bare <git-repo-url> $HOME/.myconf

Checkout the actual content from the bare repository to your $HOME:

    config checkout

The step above might fail with a message like:
```
error: The following untracked working tree files would be overwritten by checkout:
    .bashrc
    .gitignore
Please move or remove them before you can switch branches.
Aborting
```
Remove/backup existing files:
```
mkdir -p .config-backup && \
config checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | \
xargs -I{} mv {} .config-backup/{}
```
Re-run the check out if you had problems:

    config checkout

Set the flag showUntrackedFiles to no on this specific (local) repository:

    config config --local status.showUntrackedFiles no

**final script**
```bash
rm -rf $HOME/.bashrc
rm -rf $HOME/.bash_profile
rm -rf $HOME/.bash_logout
git clone --bare https://github.com/Michail-Sergievsky/dotfiles.git $HOME/.myconf
function config {
   /usr/bin/git --git-dir=$HOME/.myconf/ --work-tree=$HOME $@
}
config checkout
config config status.showUntrackedFiles no
```
After must setup git config for git bare dotfiles repository

    config config user.email "mikhail.sergiev@gmail.com"
    config config user.name "Michail-Sergievsky"

Next won't work without public key uploaded to github

    config remote set-url origin git@github.com:Michail-Sergievsky/dotfiles.git
    config push --set-upstream origin main
