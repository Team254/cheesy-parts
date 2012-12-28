$(document).ready(function() {
    $(":text:visible:enabled:first").focus();
});

function verifyPasswordMatch(form) {
  if (form.password.value == form.password2.value) {
    return true;
  } else {
    alert("The passwords do not match.");
    return false;
  }
}

function loadParts(projectId, status) {
  $.ajax({
    url: "/projects/" + projectId + "/dashboard/parts?status=" + status,
    complete: function(response) {
      $("#dashboard-parts").html(response.responseText);
    }
  });
}
