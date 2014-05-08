/* ******************************* */
/* Javascript for the article body */
/* ******************************* */

// Getting the current window width to make full size images in the article edge to edge

var classesToFind = new Array();
var imagesFound = new Array();

classesToFind.push('article-image-full');

if (window.screen.width < 768) {
    classesToFind.push('article-image');
    classesToFind.push('article-image-cartoon');
}

for (var i = 0; i < classesToFind.length; i++) {
    imagesFound.push.apply(imagesFound, document.getElementsByClassName(classesToFind[i]));
}

for (var i = 0; i < imagesFound.length; i++) {
	imagesFound[i].style.width = window.screen.width;
}