package router

type RouterGroup struct {
	BaseRouter
	UserRouter
	ImageRouter
	ArticleRouter
	CommentRouter
	FeedbackRouter
	WebsiteRouter
	HotRouter
	ConfigRouter
	MurmurRouter
}

var RouterGroupApp = new(RouterGroup)

//总路由组，根据业务分成了 10 个业务路由组
