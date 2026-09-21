/* VicThree Defence - CDS English PYQ Library: site config. */
window.VTENG_CONFIG = {
  /* LEAD CAPTURE (welcome popup -> Google Form -> linked Google Sheet).
     This site needs its OWN Google Form (do not reuse another site's).
     Paste the formResponse action URL and the three entry.xxxx ids from the
     Form's "Get pre-filled link". Leave blank to keep the popup working
     without recording anything. */
  googleForm: {
    action: "",
    fields: {
      name:  "",
      phone: "",
      email: ""
    }
  },

  /* Advanced alternative (Apps Script Web App). Ignored if googleForm is filled. */
  sheetEndpoint: ""
};
