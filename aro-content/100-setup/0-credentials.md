# Welcome to the MOBB ARO Workshop!
<p>To access your lab resources, including credentials, please enter the username provided by the facilitator.</p>
<input class="md-input" type="text" id="mkdocs-content-username" placeholder="Enter your username as provided by the facilitator" size="46">
<button class="md-button md-button--primary" id="mkdocs-redirect-button">Submit</button>

<script>
// register an event listener for the button. This can also be done using element.onlick
document.getElementById("mkdocs-redirect-button").addEventListener("click", () => {
  // get the number from the input field
  let user = document.getElementById("mkdocs-content-username").value;
  
  // construct the url to redirect to using a template string
  let url = location.protocol + '//' + location.host + '/credentials/' + user;
  
  // redirect the user to the new location
  window.open(url);
});
</script>