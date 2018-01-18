## Replicating Tableau colour pallete
require(ggthemr)
tableau_colours <- c('#1F77B4', '#FF7F0E', '#2CA02C', '#D62728', '#9467BD', '#8C564B', '#CFECF9', '#7F7F7F', '#BCBD22', '#17BECF')
# you have to add a colour at the start of your palette for outlining boxes, we'll use a grey:
tableau_colours <- c("#555555", tableau_colours)
# remove previous effects:
ggthemr_reset()
# Define colours for your figures with define_palette
tableau <- define_palette(
  swatch = tableau_colours, # colours for plotting points and bars
  gradient = c(lower = tableau_colours[1L], upper = tableau_colours[2L]), #upper and lower colours for continuous colours
  background = "#EEEEEE" #defining a grey-ish background 
)
# set the theme for your figures:
ggthemr(palette = tableau, layout ='minimal')
