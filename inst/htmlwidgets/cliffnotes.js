var test;

HTMLWidgets.widget({

  name: 'cliffnotes',

  type: 'output',

  factory: function(el, width, height) {
    // TODO: define shared variables for this instance
    return {

      renderValue: function(x) {

        ReactDOM.render(
            React.createElement(CliffNotes.DataFrameSummary, {data: x.data, el: el}),
            document.getElementById(el.id)
        );
      },

      resize: function(width, height) {
        // TODO: code to re-render the widget with a new size
      }
    };
  }
});
