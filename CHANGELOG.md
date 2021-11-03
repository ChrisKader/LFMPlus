* Removed "Show Class Colors" option that is no longer used.
* Updates to UI to make it fit better with the default UI while also allowing it to be skinned properly by skinning addons.
* Updates for changes in 9.1.5
  - Currently an API is flagged as protected (C_LFGList.GetPlaystyleString()) and the addon may generate an error related to this function being called.
  - The error cannot be avoided without crippling the LFM+ addon. The error can be safely ignored.
