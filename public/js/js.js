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

// Global variables to store current filter state for auto-refresh.
var dashboardProjectId, dashboardStatus;

function changeDashboardFilter(projectId, status) {
  dashboardProjectId = projectId;
  dashboardStatus = status;
  loadParts();
}

function loadParts() {
  $.ajax({
    url: "/projects/" + dashboardProjectId + "/dashboard/parts?status=" + dashboardStatus,
    complete: function(response) {
      $("#dashboard-parts").html(response.responseText);
      $("#dashboard-parts").tooltip({
        selector: ".dashboard-part",
        placement: "bottom"
      });
    }
  });
}

$(function() {
  $("#vendor").typeahead({
    source: vendors
  });
  $("#vendor").keypress(function(e) {
    // Disable the enter key from doing anything when no vendor is selected.
    if (e.which == 13) {
      return false;
    }
  });
});
